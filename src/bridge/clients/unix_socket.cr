module Bridge
  abstract class Client(HostT, SerializerT)
    class UnixSocket(HostT, SerializerT) < SocketClient(HostT, SerializerT, Socket::UNIXAddress)
      getter base_path : String

      def initialize(@base_path, serializer, multiplexer, @retry_time_limit = 3_u32, timeout = nil, sock_setting = NO_SPECIAL_SETTING, logger = Logger.new STDERR)
        super sock_setting, timeout, serializer, multiplexer, logger
      end

      # :nodoc:
      private def absolutize(interface_path)
        File.join base_path, interface_path
      end

      protected def generate_socket(multiplexed_interface : String)
        addr = Socket::UNIXAddress.new absolutize multiplexed_interface
        {Socket.unix, addr}
      end
    end
  end
end
