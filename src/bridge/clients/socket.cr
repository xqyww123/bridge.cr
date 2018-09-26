module Bridge
  abstract class Client(Host)
    abstract class SocketClient(Host, SockAddr) < Client(Host)
      protected abstract def generate_socket(mapped_interface : String) : {Socket, SockAddr}
      protected abstract def interface_mapping(interface : String) : String

      getter sockets = {} of String => {Socket, SockAddr}
      property retry_time_limit : UInt32 = 3

      def connect(interface_path : String) : {Socket, SockAddr}
        interface_path = interface_mapping interface_path
        @sockets[interface_path] ||= begin
          sock, addr = generate_socket interface_path
          begin
            sock.connect addr
          rescue err
            sock.close
            raise IterfaceConnectFail(Host).new addr.to_s, self, interface_path, err
          end
          {sock, addr}
        end
      end

      def rpc_call(interface_path : String, &block : IO -> _)
        retry = 0
        loop do
          sock, addr = connect interface_path
          interface_path = interface_mapping interface_path
          begin
            break yield sock
          rescue err
            case err
            when Errno
              retry = UInt32::MAX if [Errno::ENOENT, Errno::ECONNREFUSED, Errno::ENOENT, Errno::E2BIG, Errno::EACCES, Errno::EAFNOSUPPORT, Errno::EBADF].includes? err.errno
            end
            raise IterfaceConnectFail(Host).new addr.to_s, self, interface_path, err if retry >= retry_time_limit
            retry += 1
            @sockets.delete interface_path
          end
        end
      end
    end
  end
end
