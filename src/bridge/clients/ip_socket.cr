require "./socket.cr"

module Bridge
  abstract class Client(HostT, SerializerT)
    abstract class IPSocket(HostT, SerializerT) < SocketClient(HostT, SerializerT, Socket::IPAddress)
      getter server_domain : String
      getter family : ::Socket::Family
      getter blocking : Bool

      def initialize(@server_domain, family, @blocking, *args)
        @family = case family
                  when :ipv4
                    ::Socket::Family::INET
                  when :ipv6
                    ::Socket::Family::INET6
                  else
                    family
                  end.as ::Socket::Family
        super *args
      end
    end

    class TcpSocket(HostInfo, SerializerT) < IPSocket(HostInfo, SerializerT)
      getter port : Int32

      def initialize(server_domain, @port, serializer, multiplexer,
                     @retry_time_limit = 3_u32, timeout = nil,
                     family = :ipv4, blocking = false,
                     sock_setting = NO_SPECIAL_SETTING,
                     logger = Logger.new STDERR)
        super server_domain, family, blocking, sock_setting, timeout, serializer, multiplexer, logger
      end

      protected def generate_socket(multiplexed_interface : String) : {::Socket, Socket::IPAddress}
        raise "multiplexed_interface can only be #{Multiplexer::UNIQUE_INTERFACE}" unless multiplexed_interface == Multiplexer::UNIQUE_INTERFACE
        sock = ::Socket.tcp @family, @blocking
        addr = ::Socket::Addrinfo.tcp(@server_domain, @port, @family, @timeout).first.ip_address
        {sock, addr}
      end
    end

    class UdpSocket(HostInfo, SerializerT) < IPSocket(HostInfo, SerializerT)
      getter port : Int32

      def initialize(server_domain, @port, serializer, multiplexer,
                     @retry_time_limit = 3, timeout = nil,
                     family = :ipv4, blocking = false,
                     sock_setting = NO_SPECIAL_SETTING,
                     logger = Logger.new STDERR)
        super server_domain, family, blocking, sock_setting, timeout, serializer, multiplexer, logger
      end

      protected def generate_socket(multiplexed_interface : String) : {::Socket, Socket::IPAddress}
        raise "multiplexed_interface can only be #{Multiplexer::UNIQUE_INTERFACE}" unless multiplexed_interface == Multiplexer::UNIQUE_INTERFACE
        sock = ::Socket.udp @family, @blocking
        addr = ::Socket::Addrinfo.udp(@server_domain, @port, @family, @timeout).first.ip_address
        {sock, addr}
      end
    end
  end
end
