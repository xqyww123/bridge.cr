require "../error.cr"

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

      record Listening(Host), relative_path : String, proc : Proc(InterfaceArgument(Host), Nil), socket : Socket, is_server : Bool = false

      def initialize(host, @base_path, @socket_type = Socket::Type::STREAM, logger = Logger.new STDERR)
        super host, logger
        @servers = Hash(String, UNIXSocket).new Interfaces.size
        @listenings = Hash(FD, Listening).new Interfaces.size
        @group = FDGroup.new FDGroup::Events::Epollin
        @listenings_mutex = Mutex.new
      end

      private def absolutize(relative_path : String)
        File.join @base_path, relative_path
      end

      private def fd2socket(fd : FD) : UNIXSocket
        UNIXSocket.new fd, @socket_type
      end

      def bind
        return if binding?
        errs = [] of InterfaceOpenFail
        Interfaces.each do |relative_path, proc|
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

      private def add_listening(sock, relative_path, proc, *, is_server)
        @listenings_mutex.synchronize do
          @listenings[sock.fd] = Listening.new relative_path, proc, sock, is_server: is_server
        end
        @group.add sock.fd
      end

      private def remove_listening(lis)
        if lis.is_a? Socket
          lis.close
          lis = lis.fd
        end
        lis = lis.socket.fd if lis.is_a? Listening
        @group.remove lis
        @listenings_mutex.synchronize do
          @listenings.delete lis
        end
      end

      def listen
        return if listening?
        @listening = true
        bind?
        errs = [] of InterfaceFail(Host)
        @servers.each do |relative_path, sock|
          sock.listen do |errno|
            err = InterfaceListenFail.new @host, relative_path, errno
            log error, err.message
            errs << err
            next
          end
          add_listening sock, Interface::InterfaceProcs[relative_path], is_server: true
        end
        spawn do
          availables = @group.wait FDGroup::WAIT_INFINITE
          availables.each do |fd, event|
            lis = @listenings[fd]?
            unless lis
              remove_listening fd
              err = LostSocketInformation.new @host, self, fd
              log warn, err.message
              next
            end
            sock = fd2socket fd
            if event & FDGroup::Events::Epollin
              if lis.is_server?
                conn = sock.accept
              else
                conn = sock
                @group.remove conn
              end
              spawn do
                begin
                  lis.proc.call InterfaceArgument(Host).new @host, conn
                rescue err
                  excep = InterfaceExcuteFail.new @host, self, lis.relative_path, err
                  log error, excep.error
                ensure
                  @group.add conn
                end
              end
            end
            if event & FDGroup::Events::Epollhup
              remove_listening fd
              log warn, "Server #{lis.relative_path} terminated unexpectedly." if lis.is_server
            end
            if event & FDGroup::Events::Epollerr
              remove_listening fd
              if lis.is_server
                err = "Error occured in Server #{lis.relative_path}, trying to restart the server"
              else
                err = "Error occured in a calling on interface #{lis.relative_path}."
              end
              log error, err
            end
          end
        end
      end

      def stop_listen
      end

      def close
      end

      macro generate_init_apis
        Sockets = {} of String => Socket
      end

      class LostSocketInformation(Host, Driver) < DriverRunningFail(Host, Driver)
        getter fd : Int32

        def initialize(host, driver, @fd, cause = nil)
          initialize host, driver, "<unknown>", "Lost socket information to FileDescriptor #{fd}. Removing from listen list.", cause
        end
      end
    end
  end
end
