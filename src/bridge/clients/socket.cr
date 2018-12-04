module Bridge
  abstract class Client(HostT, SerializerT)
    abstract class SocketClient(HostT, SerializerT, SockAddr) < Client(HostT, SerializerT)
      protected abstract def generate_socket(multiplexed_interface : String) : {Socket, SockAddr}

      # A map from mutiplexed interface to socket information.
      getter sockets = {} of String => {Socket, SockAddr}
      property retry_time_limit : UInt32 = 3

      def connect(multiplexed_interface : String) : {Socket, SockAddr}
        @sockets[multiplexed_interface] ||= begin
          sock, addr = generate_socket multiplexed_interface
          begin
            sock.connect addr
          rescue err
            sock.close
            raise IterfaceConnectFail.new addr, self, multiplexed_interface, err
          end
          {sock, addr}
        end
      end

      def rpc_call(interface_path : String, &block : IO -> _)
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
