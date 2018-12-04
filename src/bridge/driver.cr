require "logger"
require "./mutiplex.cr"
require "./connection_injector.cr"

module Bridge
  macro def_server(name, *, driver, host, serializer, multiplex = :dynamic, **options)
    module {{name}}
      {% for k, v in options %}
      ::Bridge.def_{{k}}({{v}})
      {% end %}
      ::Bridge.def_serializer({{serializer}}) do
        alias Host = {{host}}
        ::Bridge.bind_host Binding, {{host}}, Serializer
        alias HostInfo = Binding
        alias Driver = ::Bridge::Driver::{{driver.id.camelcase}}(Binding, Serializer)
        def self.new(host : {{host}},
                     {% if multiplex != :dynamic %}
                       multiplexer = ::Bridge::Multiplexer.new_{{multiplex}},
                     {% else %}
                       multiplexer : ::Bridge::Multiplexer,
                     {% end %}
                     serializer = Serializer.new,
                     **options) : Driver
          Driver.new(
          {% if driver.is_a? Call && driver.args %}
          {% for arg in driver.args %}
            {{arg}},
          {% end %}
             **options,
          {% end %}
          {% if driver.is_a? Call && driver.named_args %}
          {% for arg in driver.named_args %}
            {{arg.name.id}}: {{arg.value}},
          {% end %}
          {% end %}
              host_binding: Binding.new(host, serializer),
              multiplexer: multiplexer
          )
        end
      end
    end
  end

  abstract class Driver(HostBinding, SerializerT) < DriverBase
    getter host_binding : HostBinding
    delegate host, serializer, to: @host_binding
    getter logger : Logger
    getter multiplexer : Multiplexer(HostBinding, SerializerT)
    getter injectors_everything
    getter injectors_multiplex
    getter injectors_calling

    def initialize(@host_binding, @multiplexer, @logger = Logger.new STDERR)
      @injectors_everything = [] of Injector::Everything(SerializerT)
      @injectors_multiplex = [] of Injector::Multiplex(SerializerT)
      @injectors_calling = [] of Injector::Calling(SerializerT)
      @logger.progname = to_s.colorize(:red).bold.to_s
    end

    macro log(type, info)
      @logger.{{type.id}}({{info}})
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
    end

    protected def call_api(multiplexed_interface : String, connection : IO)
      arg = @host_binding.make_interface_argument connection,
        Helpers.log_for @logger, ""
      @injectors_everything.each { |inj| arg = inj.inject arg }
      marg = arg
      @injectors_multiplex.each { |inj| marg = inj.inject marg }
      interface_path = @multiplexer.select multiplexed_interface, marg
      carg = arg
      @injectors_calling.each { |inj| carg = inj.inject carg }
      proc = HostBinding.interface_procs[interface_path]?
      raise log_excep error, InterfaceNotFound.new host, self, interface_path unless proc
      loop do
        begin
          proc.call @host_binding.host, carg
        rescue err
          raise log_excep error, InterfaceExcuteFail.new host, self, interface_path, err
        end
      end
    end

    tolerate bind, InterfaceBindFail(typeof(host), typeof(self))
    tolerate listen, InterfaceListenFail(typeof(host), typeof(self))

    def self.driver_name
      {{ @type.name.gsub(/^Bridge::Driver::([a-zA-Z0-9]*).*$/, "\\1").stringify }}
    end

    def to_s(io : IO)
      io << host << " on Driver " << self.class.driver_name
    end

    def inspect(io : IO)
      to_s io
    end
  end
end

require "./drivers/*"
