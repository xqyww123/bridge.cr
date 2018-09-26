require "../error.cr"

module Bridge
  abstract class Driver
    abstract class SocketDriver(Host, SockAddr) < Driver(Host)
      alias FD = Int

      property retry_time_limit : Int32 = 32
      property connection_retry_time_limit : Int32 = 32
      getter servers : Hash(String, ServerInfo(Host, SockAddr))

      abstract def generate_socket(interface : String) : Socket
      abstract def generate_socket_address(interfaces : Iterator(String)) : Iterator({String, SockAddr})

      class ServerInfo(Host, SockAddr)
        getter relative_path : String
        getter proc : Proc(Bridge::Host::InterfaceArgument(Host), Nil)
        getter addr : SockAddr
        property sock : Socket?
        property? listening : Bool = false

        def initialize(@relative_path, @proc, @addr, @sock = nil)
        end

        def binding?
          !!sock
        end
      end

      def initialize(host : Host, logger = Logger.new STDERR)
        super host, logger
        @servers = Hash(String, ServerInfo(Host, SockAddr)).new nil, Host.interfaces.size
        generate_socket_address(Host.interfaces.each_key).each do |relative_path, sock_addr|
          @servers[relative_path] = ServerInfo(Host, SockAddr).new relative_path, Host.interface_procs[relative_path], sock_addr
        end
      end

      def bind
        errs = [] of InterfaceBindFail(Host)
        @servers.each_value do |server|
          next if server.binding?
          log info, "binding #{@host}:#{server.relative_path} on #{server.addr}"
          sock = generate_socket server.relative_path
          fail = false
          sock.bind(server.addr) do |errno|
            err = InterfaceBindFail.new @host, self, server.relative_path, errno
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

      def binding?(interface_path)
        if interface_path.is_a? ServerInfo
          interface_path.binding?
        else
          @servers[interface_path].binding?
        end
      end

      def listening?
        @servers.each_value.any? &.listening?
      end

      def listening?(interface_path)
        if interface_path.is_a? ServerInfo
          interface_path.listening?
        else
          @servers[interface_path]?.try &.listening?
        end
      end

      def listen
        bind?
        errs = [] of InterfaceListenFail(Host)
        @servers.each_value do |lis|
          next unless sock = lis.sock
          sock.listen do |errno|
            err = InterfaceListenFail(Host).new @host, self, lis.relative_path, errno
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
                log info, "new connection on #{@host}:#{lis.relative_path}"
                break unless conn1
                spawn do
                  begin
                    conn = conn1.not_nil!
                    conn_retry_times = 0
                    loop do
                      retry = false
                      begin
                        break if conn.peek.empty?
                        log info, "executing #{@host}:#{lis.relative_path}"
                        retry = true
                        lis.proc.call Bridge::Host::InterfaceArgument(Host).new @host, conn
                      rescue err
                        excep = InterfaceExcuteFail.new @host, self, lis.relative_path, err
                        log error, excep.message
                        raise ConnectionRetryTimeout.new @host, self, lis.relative_path if conn_retry_times > connection_retry_time_limit
                        conn_retry_times += 1
                        break unless retry
                      end
                    end
                    log info, "connection of #{@host}:#{lis.relative_path} terminated"
                  rescue err
                    log error, ConnectionTerminated.new(@host, self, lis.relative_path, err)
                  end
                end
              end
            rescue err
              log warn, Errno.new("Error occured in Server #{lis.relative_path}, trying to restart the server").message
              sock.not_nil!.close if sock = lis.sock
              lis.sock = nil
              listen
            end
          end
        end
      end

      def stop_listen
        @servers.each do |server|
          server.sock.close
          server.sock = nil
        end
      end

      def close
        stop_listen
        @servers.clear
      end
    end
  end
end
