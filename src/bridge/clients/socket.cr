module Bridge
  abstract class Client(HostT, SerializerT)
    abstract class SocketClient(HostT, SerializerT, SockAddr) < Client(HostT, SerializerT)
      protected abstract def generate_socket(multiplexed_interface : String) : {Socket, SockAddr}

      # A map from mutiplexed interface to socket information.
      getter sockets = {} of String => {Socket, SockAddr}
      property retry_time_limit : UInt32 = 3
      getter sock_setting

      NO_SPECIAL_SETTING = ->(sock : Socket) {}

      def initialize(@sock_setting : Proc(Socket, Nil) = NO_SPECIAL_SETTING, *args)
        super *args
      end

      def connect(multiplexed_interface : String) : {Socket, SockAddr}
        @sockets[multiplexed_interface] ||= begin
          sock, addr = generate_socket multiplexed_interface
          begin
            sock.connect addr, timeout: @timeout
          rescue err
            sock.close
            raise IterfaceConnectFail.new addr, self, multiplexed_interface, err
          end
          sock.read_timeout = @timeout.not_nil! if @timeout
          sock.write_timeout = @timeout.not_nil! if @timeout
          sock_setting.call sock
          {sock, addr}
        end
      end

      def rpc(interface_path : String, &block : IO -> _)
        retry = 0
        loop do
          multiplexed_interface = @multiplexer.multiplex interface_path
          sock, addr = connect multiplexed_interface
          begin
            break call_server interface_path, sock, &block
          rescue err
            case err
            when Errno
              retry = UInt32::MAX if [Errno::ENOENT, Errno::ECONNREFUSED, Errno::ENOENT, Errno::E2BIG, Errno::EACCES, Errno::EAFNOSUPPORT, Errno::EBADF].includes? err.errno
            end
            raise IterfaceConnectFail.new addr, self, interface_path, err if retry >= retry_time_limit
            retry += 1
            @sockets.delete interface_path
          end
        end
      end
    end
  end
end
