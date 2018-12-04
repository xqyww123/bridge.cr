require "./socket.cr"

module Bridge
  abstract class Driver
    class UnixSocket(Host, SerializerT) < SocketDriver(Host, SerializerT, Socket::UNIXAddress)
      Family = Socket::Family::UNIX
      getter base_path : String
      getter socket_type : Socket::Type

      def initialize(host_binding : Host, @base_path, multiplexer = Multiplexer::NoMultiplex(Host).new, @socket_type = Socket::Type::STREAM, logger = Logger.new STDERR)
        super host_binding, multiplexer, logger
      end

      def absolutize(relative_path : String)
        File.join @base_path, relative_path
      end

      def generate_socket(interface : String)
        path = absolutize interface
        Dir.mkdir_p File.dirname path
        UNIXSocket.new Socket::Family::UNIX, @socket_type
      end

      def generate_socket_address(interface : String)
        Socket::UNIXAddress.new absolutize interface
      end

      def multiplex(interfaces : Array(String)) : Iterator({String, String})
        interfaces.each.map do |origin_interfaces|
          {origin_interfaces, origin_interfaces}
        end
      end
    end
  end
end
