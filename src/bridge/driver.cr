require "logger"

module Bridge
  abstract class Driver(Host)
    getter host : Host
    getter logger : Logger

    def initialize(@host, @logger = Logger.new STDERR)
    end

    macro log(type, info)
      @logger.{{type.id}}({{info}}, self)
    end

    macro log_excep(type, excep)
      begin
        %excep = excep
        log {{type.id}}, %excep.message
        %excep
      end
    end

    abstract def bind
    abstract def binding?
    abstract def listen
    abstract def listening?
    # pause the listening, could resume by calling `listen` again
    abstract def stop_listen
    # which will de-bind and release everything
    abstract def close

    macro tolerate(operation, *fails)
      def {{operation}}?
        begin
          {{operation}}
        {% for fail in fails %}
        rescue err : SomeFail({{fail}}, Host)
        {% end %}
        end
      end

      private def call_api(interface_path : String, arg : Bridge::Host::InterfaceArgument(Host))
        proc = @host.interface_procs[interface_path]?
        raise log_excep error, InterfaceNotFound(Host).new @host, self, interface_path unless proc
        begin
          proc.call arg
        rescue err
          raise log_excep error, InterfaceExcuteFail.new @host, self, interface_path, err
        end
      end
    end

    tolerate bind, InterfaceBindFail(Host)
    tolerate listen, InterfaceListenFail(Host)

    def to_s(io : IO)
      io << self.class
    end
  end
end

require "./drivers/*"
