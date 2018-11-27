require "logger"
require "./mutiplex.cr"
require "./connection_injector.cr"

module Bridge
  abstract class Driver(HostBinding)
    getter host_binding : HostBinding
    delegate host, serializer, to: @host_binding
    getter logger : Logger
    getter multiplexer : Multiplexer(HostBinding)
    getter injectors_everything
    getter injectors_multiplex
    getter injectors_calling

    def initialize(@host_binding, @multiplexer, @logger = Logger.new STDERR)
      @injectors_everything = [] of Injector::Everything(HostBinding)
      @injectors_multiplex = [] of Injector::Multiplex(HostBinding)
      @injectors_calling = [] of Injector::Calling(HostBinding)
    end

    macro log(type, info)
      @logger.{{type.id}}({{info}}, self)
    end

    macro log_excep(type, excep)
      begin
        %excep = {{excep}}
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
        rescue err : SomeFail({{fail}}, typeof(host))
        {% end %}
        end
      end

      protected def call_api(multiplexed_interface : String, connection : IO)
        arg = @host_binding.make_interface_argument connection
        @injectors_everything.each {|inj| arg = inj.inject arg }
        marg = arg
        @injectors_multiplex.each {|inj| marg = inj.inject marg }
        carg = arg
        @injectors_calling.each {|inj| carg = inj.inject carg }
        interface_path = @multiplexer.select multiplexed_interface, marg
        proc = HostBinding.interface_procs[interface_path]?
        raise log_excep error, InterfaceNotFound.new host, self, interface_path unless proc
        loop do
          begin
            proc.call carg
          rescue err
            raise log_excep error, InterfaceExcuteFail.new host, self, interface_path, err
          end
        end
      end
    end

    tolerate bind, InterfaceBindFail(typeof(host), typeof(self))
    tolerate listen, InterfaceListenFail(typeof(host), typeof(self))

    def to_s(io : IO)
      io << host << " on " << self.class
    end
  end
end

require "./drivers/*"
