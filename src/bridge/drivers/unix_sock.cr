require "./socket.cr"

module Bridge
  abstract class Driver
    class UnixSocket(Host) < SocketDriver(Host, Socket::UNIXAddress)
      Family = Socket::Family::UNIX
      getter base_path : String
      getter socket_type : Socket::Type

      def initialize(host : Host, @base_path, @socket_type = Socket::Type::STREAM, logger = Logger.new STDERR)
        super host, logger
      end

      def absolutize(relative_path : String)
        File.join @base_path, relative_path
      end

      def generate_socket(interface : String)
        path = absolutize interface
        Dir.mkdir_p File.dirname path
        UNIXSocket.new Socket::Family::UNIX, @socket_type
      end

      def generate_socket_address(interfaces : Iterator(String))
        interfaces.map do |relative_path|
          {relative_path, Socket::UNIXAddress.new(absolutize relative_path)}
        end
      end

      def client(interface : String) : Socket
        UNIXSocket.new ZooServer.absolutize interface
      end
    end
  end
end
