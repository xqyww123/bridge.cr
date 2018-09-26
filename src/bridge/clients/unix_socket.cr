module Bridge
  abstract class Client(Host)
    class UnixSocket(Host) < SocketClient(Host, Socket::UNIXAddress)
      getter base_path : String

      def initialize(@base_path)
      end

      def absolutize(interface_path)
        File.join base_path, interface_path
      end

      protected def generate_socket(mapped_interface : String)
        addr = Socket::UNIXAddress.new absolutize mapped_interface
        {Socket.unix, addr}
      end

      protected def interface_mapping(interface : String)
        interface
      end
    end
  end
end
