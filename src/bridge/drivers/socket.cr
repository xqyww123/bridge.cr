require "../error.cr"

module Bridge
  abstract class Driver
    # A general purposed socket dirver.
    abstract class SocketDriver(HostBinding, SockAddr) < Driver(HostBinding)
      # Tolerance limit of the error in a connection. Exceeding the limit, the connection will terminate by force.
      property connection_retry_time_limit : Int32 = 32
      @servers : Hash(String, ServerInfo(HostBinding, SockAddr))

      # All the server running, a map from the multiplexed to `ServerInfo`.
      def servers : Mapping(String, ServerInfo(HostBinding, SockAddr))
        @servers
      end

      # generate a `Socket` given the `multiplexed_interface`
      abstract def generate_socket(multiplexed_interface : String) : Socket
      # generate the `SockAddr` given the `multiplexed_interface`
      abstract def generate_socket_address(multiplexed_interfaces : String) : SockAddr

      class ServerInfo(HostBinding, SockAddr)
        getter multiplexed_interface : String
        getter addr : SockAddr
        property sock : Socket?
        property? listening : Bool = false

        def initialize(@multiplexed_interface, @addr, @sock = nil)
        end

        # Whether the server bound.
        def binding?
          !!@sock
        end
      end

      def initialize(host : HostBinding, multiplexer = nil, logger = Logger.new STDERR)
        super host, multiplexer, logger
        @servers = Hash(String, ServerInfo(HostBinding, SockAddr)).new nil, @multiplexer.multiplexed_size
        HostBinding.interfaces.keys.each do |origin_interface|
          multiplexed_interface = @multiplexer.multiplex origin_interface
          server = ServerInfo(HostBinding, SockAddr).new multiplexed_interface, generate_socket_address(multiplexed_interface)
          @servers[origin_interface] = server
        end
      end

      def bind
        errs = [] of InterfaceBindFail(typeof(host), typeof(self))
        @servers.each_value do |server|
          next if server.binding?
          log info, "binding #{host}:#{server.multiplexed_interface} on #{server.addr}"
          sock = generate_socket server.multiplexed_interface
          fail = false
          sock.bind(server.addr) do |errno|
            err = InterfaceBindFail.new host, self, server.multiplexed_interface, errno
            log error, err.message
            errs << err
            fail = true
          end
          server.sock = sock unless fail
        end
        raise SomeFail.new errs, self unless errs.empty?
      end

      def binding?
        @servers.each_value.any? &.binding?
      end

      # `interface_path` could be a `ServerInfo` or origin interface.
      def binding?(interface_path)
        if interface_path.is_a? ServerInfo
          interface_path.binding?
        else
          @servers[@multiplexer.multiplex interface_path].binding?
        end
      end

      def listening?
        @servers.each_value.any? &.listening?
      end

      # `interface_path` could be a `ServerInfo` or origin interface.
      def listening?(interface_path)
        if interface_path.is_a? ServerInfo
          interface_path.listening?
        else
          @servers[@multiplexer.multiplex interface_path]?.try &.listening?
        end
      end

      def listen
        bind?
        errs = [] of InterfaceListenFail(typeof(host), typeof(self))
        @servers.each_value do |lis|
          next unless sock = lis.sock
          sock.listen do |errno|
            err = InterfaceListenFail.new host, self, lis.multiplexed_interface, errno
            log error, err.message
            errs << err
            next
          end
        end
        @servers.each_value do |lis|
          next unless sock = lis.sock
          spawn do
            begin
              loop do
                conn1 = sock.not_nil!.accept?
                break unless conn1
                log info, "new connection on mutiplexed #{host}:#{lis.multiplexed_interface}"
                spawn do
                  call_api(lis.multiplexed_interface, conn1.not_nil!)
                end
              rescue err
                log warn, Errno.new("Error occured in Server #{lis.multiplexed_interface}, trying to restart the server").message
                sock.not_nil!.close if sock = lis.sock
                lis.sock = nil
                listen
              end
            end
          end
        end
      end

      def stop_listen
        @all_servers.each do |server|
          server.sock.close
          server.sock = nil
        end
      end

      def close
        stop_listen
        @all_servers.clear
        @servers.clear
      end
    end
  end
end
