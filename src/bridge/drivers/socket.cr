require "mutex.cr "

module Bridge
  abstract class Driver
    class UnixSocket(Host) < Driver(Host)
      alias Connection = UNIXSocket
      alias FDGroup = IO::FileDescriptor::Group
      alias FD = FDGroup::FD

      Family = Socket::Family::UNIX

      getter base_path : String
      getter? listening : Bool = false
      getter socket_type : Socket::Type
      getter servers : Hash(String, UNIXSocket)

      record Listening, relative_path : String, proc : Host::InterfaceProc, fiber : Fiber, is_server : Bool = false

      def initialize(host, @base_path, @socket_type = Socket::Type::STREAM, logger = Logger.new STDERR)
        super host, logger
        @servers = Hash(String, UNIXSocket).new Host::Interfaces.size
        @listenings = Hash(FD, Listening).new Host::Interfaces.size
        @group = FDGroup.new FDGroup::Events::Epollin
        @listenings_mutex = Mutex.new
      end

      private def absolutize(relative_path : String)
        File.join @base_path, relative_path
      end

      private def is_server?(fd : FD)
        @servers_path[fd]?
      end

      private def fd2socket(fd : FD) : UNIXSocket
        UNIXSocket.new fd, @socket_type
      end

      def bind
        return if binding?
        errs = [] of InterfaceOpenFail
        Host::Interfaces.each do |relative_path, proc|
          server = UNIXSocket.new Family, @socket_type
          server.bind UNIXAddress.new absolutize relative_path do |errno|
            err = InterfaceBindFail.new @host, relative_path, errno
            log error, err.message
            errs << err
            next
          end
          @servers[relative_path] = server
          @servers_path[server.fd] = relative_path
        end
        raise SomeFail.new errs unless errs.empty?
      end

      def binding?
        !@servers.empty?
      end

      private def add_listening(sock, relative_path, proc)
        @listenings_mutex.synchronize do
          @listenings[sock.fd] = Listening.new relative_path, proc
        end
        @group.add server
      end

      def listen
        return if listening?
        @listening = true
        bind?
        errs = [] of InterfaceListenFail
        @servers.each do |relative_path, sock|
          sock.listen do |errno|
            err = InterfaceListenFail.new @host, relative_path, errno
            log error, err.message
            errs << err
            next
          end
          add_listening sock, Interface::InterfaceProcs[relative_path]
        end
        spawn do
          availables = @group.wait FDGroup::WAIT_INFINITE
          availables.each do |fd, event|
            proc = @listenings[fd]?
            unless proc
              @group.remove fd
              log warn, "lost socket information to FileDescriptor #{fd}, removed from listen list."
              next
            end
            sock = fd2socket fd
            if event & FDGroup::Events::Epollin
              if is_server? fd
                conn = sock.accept
                spawn do
                  proc.call Host::InterfaceArgument.new @host, conn
                  add_listening conn, proc
                  Fiber.sleep -1
                end
              else
              end
            end
            if event & FDGroup::Events::Epollhup
              if relative_path = is_server? fd
                log warn, "Server #{relative_path} terminated unexpectedly."
                @group.remove fd
                sock.close
              else
                # TODO
              end
            end
          end
        end
      end

      def stop
      end

      macro generate_init_apis
        Sockets = {} of String => Socket
      end
    end
  end
end
