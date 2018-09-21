require "logger"

module Bridge
  abstract class Driver(Host)
    getter host : Host
    getter logger : Logger

    def initialize(@host, @logger = Logger.new STDERR)
    end

    def call_api(relative_path : String)
      err = InterfaceNotFound(Host).new @host, relative_path
      log error, err.message
      raise err
    end

    PROGRAM_NAME = "Bridge #{Host} on #{self}"

    macro log(type, info)
      @logger.{{type.id}}({{info}}, PROGRAM_NAME)
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
        rescue err : SomeFail({{fail}})
        {% end %}
        end
      end
    end

    tolerate bind, InterfaceBindFail
    tolerate listen, InterfaceListenFail
  end
end

require "./drivers/*"
