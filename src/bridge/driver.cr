require "logger"
require "./mutiplex.cr"
require "./connection_injector.cr"

module Bridge
  macro def_server(name, *, driver, host, serializer, multiplex = :dynamic,
                   injectors_everything = nil,
                   injectors_multiplex = nil,
                   injectors_calling = nil, **options)
    module {{name}}
      {% for k, v in options %}
      ::Bridge.def_{{k}}({{v}})
      {% end %}
      ::Bridge.def_serializer({{serializer}}) do
        alias Host = {{host}}
        ::Bridge.bind_host Binding, {{host}}, Serializer
        alias HostInfo = Binding
        alias Driver = ::Bridge::Driver::{{driver.name.camelcase}}(Binding, Serializer)
        def self.new(host : {{host}},
                     {% if multiplex != :dynamic %}
                       multiplexer = ::Bridge::Multiplexer.new_{{multiplex}},
                     {% else %}
                       multiplexer : ::Bridge::Multiplexer,
                     {% end %}
                     serializer = Serializer.new,
                     **options) : Driver
          ret = Driver.new(
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
        ::Bridge::Injector.add_injectors ret, {{injectors_everything}}, {{injectors_multiplex}}, {{injectors_calling}}
          ret
        end

        ::Bridge::Multiplexer.config_{{multiplex}}
        ::Bridge::Injector.config_injectors({{injectors_everything}}, {{injectors_multiplex}}, {{injectors_calling}})
        module Config
          OVERALL = {interfaces: Host::Interfaces,
            driver: Driver.config(
              {% if driver.is_a? Call && driver.args %}
              {% for arg, ind in driver.args %}
                {{arg}},
              {% end %} {% end %}
              {% if driver.is_a? Call && driver.named_args %}
              {% for arg in driver.named_args %}
                {{arg.name.id}}: {{arg.value}},
              {% end %} {% end %}),
            serializer: SERIALIZER,
            multiplex: MULTIPLEX,
            injectors_everything: INJECTORS_EVERYTHING,
            injectors_calling: INJECTORS_CALLING,
            injectors_multiplex: INJECTORS_MULTIPLEX
          }
        end
        CONFIG = Config::OVERALL
      end
    end
  end

  abstract class Driver(HostBinding, SerializerT) < DriverBase
    include Helpers::Mixin

    getter host_binding : HostBinding
    delegate host, serializer, to: @host_binding
    getter logger : Logger
    getter multiplexer : Multiplexer(HostBinding, SerializerT)
    getter injectors_everything
    getter injectors_multiplex
    getter injectors_calling

    def initialize(@host_binding, @multiplexer, @logger = Logger.new STDERR)
      @injectors_everything = [] of Injector(SerializerT)
      @injectors_multiplex = [] of Injector(SerializerT)
      @injectors_calling = [] of Injector(SerializerT)
      @logger.progname = to_s.colorize(:yellow).bold.to_s
    end

    abstract def bind
    abstract def binding?
    abstract def listen
    abstract def listening?
    # pause the listening, could resume by calling `listen` again
    abstract def stop_listen
    # which will de-bind and release everything
    abstract def close

    # shutdown all connection related to `interface_path`.
    # All unreceived data lost, sends `InterfaceClosed` to the connection reading incompleted, waits `timeout` for the reading completed or executing. If timeout, kill the execution forcelly.
    # If `timeout` is 0, kill the execution directly.
    # If `timeout` is nil, wait the execution for ever.
    abstract def kill(interface_path : String, timeout : Time::Span? | Int = nil) : Channel(Nil)
    abstract def kill_all(timeout : Time::Span? | Int = nil) : Channel(Nil)

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

    tolerate bind, InterfaceBindFail(typeof(host), typeof(self))
    tolerate listen, InterfaceListenFail(typeof(host), typeof(self))

    protected def call_api(multiplexed_interface : String, connection : IO)
      arg = @host_binding.make_interface_argument connection,
        Helpers.log_for @logger, "#{host}:#{multiplexed_interface}"
      @injectors_everything.each { |inj| arg = inj.inject arg }
      marg = arg
      @injectors_multiplex.each { |inj| marg = inj.inject marg }
      carg = arg
      @injectors_calling.each { |inj| carg = inj.inject carg }
      loop do
        begin
          log_debug "waiting on #{host}:#{multiplexed_interface}."
          interface_path = @multiplexer.select multiplexed_interface, marg
          proc = HostBinding.interface_procs[interface_path]?
          raise log_error InterfaceNotFound.new host, self, interface_path unless proc
          proc.call @host_binding.host, carg
        rescue err : IO::Timeout
          log_info "Timeout, long connection ##{connection.fd} terminated #{host}."
          break
        rescue err : InterfaceNotFound
          raise err
        rescue err
          raise log_error InterfaceExcuteFail.new host, self, (interface_path || "<mutiplex fail>"), err
        end
      end
    end

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
