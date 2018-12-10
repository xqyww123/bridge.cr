require "../error.cr"

module Bridge
  abstract class Driver
    # A general purposed socket dirver.
    abstract class SocketDriver(HostBinding, SerializerT, SockAddr) < Driver(HostBinding, SerializerT)
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

      record ConnectionInfo(HostBinding, SockAddr), interface_path : String, server_info : ServerInfo(HostBinding, SockAddr)

      getter timeout : Time::Span?
      @sock_setting : Proc(Socket, Nil)

      # number of connected
      def connection_number
        @connections.size
      end

      def initialize(host : HostBinding, multiplexer, @timeout, @sock_setting, logger)
        super host, multiplexer, logger
        @connections = {} of Socket => ConnectionInfo(HostBinding, SockAddr)
        @servers = Hash(String, ServerInfo(HostBinding, SockAddr)).new nil, @multiplexer.multiplexed_size
        HostBinding.interfaces.keys.each do |origin_interface|
          multiplexed_interface = @multiplexer.multiplex origin_interface
          @servers[multiplexed_interface] ||=
            ServerInfo(HostBinding, SockAddr).new multiplexed_interface, generate_socket_address(multiplexed_interface)
        end
      end

      NO_SPECIAL_SETTING = ->(a : ::Socket) {}

      private def config_socket(sock : ::Socket)
        @sock_setting.call sock
      end

      private def config_connection(sock : ::Socket)
        sock.read_timeout = @timeout.not_nil! if @timeout
        sock.write_timeout = @timeout.not_nil! if @timeout
      end

      def bind
        errs = [] of InterfaceBindFail(typeof(host), typeof(self))
        @servers.each_value do |server|
          next if server.binding?
          log_info "binding #{host}:#{server.multiplexed_interface} on #{server.addr}"
          sock = generate_socket server.multiplexed_interface
          config_socket sock
          fail = false
          sock.bind(server.addr) do |errno|
            err = InterfaceBindFail.new host, self, server.multiplexed_interface, errno
            log_error err.message
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
          log_info "listening #{host}:#{lis.multiplexed_interface}"
          sock.listen do |errno|
            err = InterfaceListenFail.new host, self, lis.multiplexed_interface, errno
            log_error err.message
            errs << err
            next
          end
        end
        @servers.each_value do |lis|
          next unless sock = lis.sock
          spawn do
            begin
              loop do
                conn = sock.not_nil!.accept?
                break if conn.nil?
                config_connection conn
                log_info "new connection ##{conn.fd} on mutiplexed #{host}:#{lis.multiplexed_interface}"
                spawn do
                  conn1 = conn.not_nil!
                  # BUG ! should be original_interface
                  @connections[conn1] = ConnectionInfo.new lis.multiplexed_interface, lis
                  begin
                    call_api(lis.multiplexed_interface, conn1)
                  rescue
                  ensure
                    @connections.delete conn1
                    conn1.close
                  end
                end
              rescue err
                log_warn "Error occured in Server #{lis.multiplexed_interface}, trying to restart the server : #{err}"
                sock.not_nil!.close if sock = lis.sock
                lis.sock = nil
                listen
              end
            end
          end
        end
      end

      def stop_listen
        @servers.each_value do |server|
          log_info "closing #{host}:#{server.multiplexed_interface}"
          server.sock.try &.close
          server.sock = nil
        end
      end

      def close
        stop_listen
        @servers.clear
      end

      private def kill(socks : Iterator({Socket, ConnectionInfo(HostBinding, SockAddr)}), timeout = nil)
        raise "non-nil timeout to kill still not supported" if timeout
        socks.each &.first.close_read
      end

      def kill(interface_path = nil)
        kill @connections.each.select(&.last.interface_path.== interface_path).to_a.each
      end

      def kill_all(timeout = nil)
        kill @connections.to_a.each
      end
    end
  end
end
