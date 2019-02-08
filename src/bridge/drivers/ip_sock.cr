require "./socket.cr"

module Bridge
  abstract class Driver
    abstract class IPSocket(HostBinding, SerializerT) < SocketDriver(HostBinding, SerializerT, Socket::IPAddress)
      getter family : ::Socket::Family
      getter blocking : Bool
      getter domain : String

      def initialize(host_binding : HostBinding, @domain, family, @blocking, multiplexer, timeout, sock_setting, logger)
        @family = case family
                  when :ipv4
                    ::Socket::Family::INET
                  when :ipv6
                    ::Socket::Family::INET6
                  else
                    family
                  end.as ::Socket::Family
        super host_binding, multiplexer, timeout, sock_setting, logger
      end
    end

    class TcpSocket(HostBinding, SerializerT) < IPSocket(HostBinding, SerializerT)
      TransportProtocal = ::Socket::Protocal::TCP
      getter port : Int32

      def initialize(host_binding : HostBinding, domain : String, @port,
                     multiplexer,
                     family = ::Socket::Family::INET,
                     blocking = false, timeout = nil,
                     logger = Logger.new(STDERR),
                     sock_setting = NO_SPECIAL_SETTING)
        super host_binding, domain, family, blocking, multiplexer, timeout, sock_setting, logger
      end

      def generate_socket(multiplexed_interface : String) : ::Socket
        Socket.tcp @family, @blocking
      end

      def generate_socket_address(multiplexed_interface : String) : ::Socket::IPAddress
        ::Socket::Addrinfo.tcp(@domain, @port, @family, @timeout).first.ip_address
      end

      macro config(domain, port, **options)
        {_name_: "TcpSocket", domain: {{domain}}, port: {{port}}}
      end
    end

    class UdpSocket(HostBinding, SerializerT) < IPSocket(HostBinding, SerializerT)
      TransportProtocal = ::Socket::Protocal::UDP
      getter port : Int32

      def initialize(host_binding : HostBinding, domain : String, @port,
                     family = ::Socket::Family::INET,
                     blocking = false, multiplexer = nil, timeout = nil,
                     logger = Logger.new(STDERR),
                     sock_setting = NO_SPECIAL_SETTING)
        super host_binding, domain, family, blocking, multiplexer, timeout, sock_setting, logger
      end

      def generate_socket_address(multiplexed_interface : String) : ::Socket::IPAddress
        ::Socket::Addrinfo.udp(@domain, @port, @family, @timeout).first.ip_address
      end

      def generate_socket(multiplexed_interface : String) : ::Socket
        Socket.udp @family, @blocking
      end

      macro config(domain, port, **options)
        {_name_: "UdpSocket", domain: {{domain}}, port: {{port}}}
      end
    end
  end
end
