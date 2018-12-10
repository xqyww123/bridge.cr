module Bridge
  abstract class Client(HostT, SerializerT)
    abstract class SocketClient(HostT, SerializerT, SockAddr) < Client(HostT, SerializerT)
      protected abstract def generate_socket(multiplexed_interface : String) : {Socket, SockAddr}

      record ConnectionInfo(SerializerT, SockAddr), info : Client::ConnectionInfo(SerializerT), addr : SockAddr do
        delegate multiplexed_interface, multiplex_argument, calling_argument, connection, to: @info
      end
      # A map from mutiplexed interface to socket information.
      getter sockets
      property retry_time_limit : UInt32 = 3
      getter sock_setting

      NO_SPECIAL_SETTING = ->(sock : Socket) {}

      def initialize(@sock_setting : Proc(Socket, Nil) = NO_SPECIAL_SETTING, *args)
        @sockets = {} of String => ConnectionInfo(SerializerT, SockAddr)
        super *args
      end

      protected def config_new_connection(multiplexed_interface : String, sock : Socket, addr : SockAddr)
        @sock_setting.call sock
        sock.read_timeout = @timeout.not_nil! if @timeout
        sock.write_timeout = @timeout.not_nil! if @timeout
        info = super multiplexed_interface, sock
        ConnectionInfo(SerializerT, SockAddr).new info, addr
      end

      def connect(multiplexed_interface : String)
        @sockets[multiplexed_interface] ||= begin
          sock, addr = generate_socket multiplexed_interface
          begin
            log_info "connecting to #{addr} at ##{sock.fd} for multiplexed #{HostT}:#{multiplexed_interface}"
            sock.connect addr, timeout: @timeout
          rescue err
            sock.close
            raise log_error IterfaceConnectFail.new addr, self, multiplexed_interface, err
          end
          config_new_connection multiplexed_interface, sock, addr
        end
      end

      def rpc(interface_path : String, &block : IO -> _)
        retry = 0
        loop do
          multiplexed_interface = @multiplexer.multiplex interface_path
          conn = connect multiplexed_interface
          begin
            break call_server interface_path, conn.info, &block
          rescue err
            case err
            when IO::Timeout
              retry = UInt32::MAX
            when Errno
              retry = UInt32::MAX if [Errno::ENOENT, Errno::ECONNREFUSED, Errno::ENOENT, Errno::E2BIG, Errno::EACCES, Errno::EAFNOSUPPORT, Errno::EBADF].includes? err.errno
            end
            @sockets.delete multiplexed_interface
            conn.connection.close
            if retry >= retry_time_limit
              raise log_error IterfaceConnectFail.new conn.addr, self, interface_path, err
            else
              log_warn "fail to connect #{conn.addr} for #{HostT}:#{interface_path} for #{retry + 1} times: #{err}"
            end
            retry += 1
          end
        end
      end
    end
  end
end
