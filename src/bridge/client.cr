require "logger"

module Bridge
  abstract class Client(HostT, SerializerT)
    include Helpers::Mixin

    getter serializer : SerializerT
    getter multiplexer : Multiplexer(HostT, SerializerT)
    getter injectors_everything
    getter injectors_multiplex
    getter injectors_calling
    getter logger : Logger?
    getter timeout : Time::Span?

    def initialize(@timeout, @serializer, @multiplexer, @logger = nil)
      @injectors_everything = [] of Injector(SerializerT)
      @injectors_multiplex = [] of Injector(SerializerT)
      @injectors_calling = [] of Injector(SerializerT)
      @logger.try &.progname = to_s.colorize(:green).bold.to_s
    end

    abstract def rpc(interface_path : String, &users_process : IO -> _)

    record ConnectionInfo(SerializerT), multiplexed_interface : String, multiplex_argument : InterfaceArgument(SerializerT), calling_argument : InterfaceArgument(SerializerT), connection : IO

    protected def config_new_connection(multiplexed_interface : String, connection : IO) : ConnectionInfo(SerializerT)
      arg = InterfaceArgument(SerializerT).new @serializer, connection, @logger, InterfaceDirection::ToServer
      @injectors_everything.each { |inj| arg = inj.inject arg }
      marg = arg
      @injectors_multiplex.each { |inj| marg = inj.inject marg }
      carg = arg
      @injectors_calling.each { |inj| carg = inj.inject carg }
      ConnectionInfo.new multiplexed_interface, marg, carg, connection
    end

    protected def call_server(interface_path : String, connection : ConnectionInfo, &users_process : IO -> _)
      @multiplexer.multiplex interface_path, connection.multiplex_argument
      yield connection.calling_argument.connection
    end

    def self.client_name
      {{ @type.name.gsub(/^Bridge::Client::([a-zA-Z0-9]*).*$/, "\\1").stringify }}
    end

    def to_s(io : IO)
      io << HostT << " on Client " << self.class.client_name
    end
  end
end

require "./clients/*"
