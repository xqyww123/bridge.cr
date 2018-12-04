require "logger"

module Bridge
  abstract class Client(HostT, SerializerT)
    getter serializer : SerializerT
    getter multiplexer : Multiplexer(HostT, SerializerT)
    getter injectors_everything
    getter injectors_multiplex
    getter injectors_calling
    getter logger : Logger

    def initialize(@serializer, @multiplexer, @logger)
      @injectors_everything = [] of Injector::Everything(SerializerT)
      @injectors_multiplex = [] of Injector::Multiplex(SerializerT)
      @injectors_calling = [] of Injector::Calling(SerializerT)
      @logger.progname = to_s.colorize(:light_blue).bold.to_s
    end

    abstract def rpc_call(interface_path : String, &users_process : IO -> _)

    protected def call_server(interface_path : String, io : IO, &users_process : IO -> _)
      arg = InterfaceArgument(SerializerT).new @serializer, io, @logger, InterfaceDirection::ToServer
      @injectors_everything.each { |inj| arg = inj.inject arg }
      marg = arg
      @injectors_multiplex.each { |inj| marg = inj.inject marg }
      carg = arg
      @injectors_calling.each { |inj| carg = inj.inject carg }
      @multiplexer.multiplex interface_path, marg
      yield carg.connection
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
