require "io/hexdump"

module Bridge
  class Injector(SerializerT)
    class Hexdump(SerializerT) < Injector(SerializerT)
      getter dump_to, read, write

      def initialize(@dump_to : IO? = nil, @read : Bool = true, @write : Bool = false)
      end

      def inject(arg : InterfaceArgument(SerializerT)) : InterfaceArgument(SerializerT)
        arg.wrap connection: IO::Hexdump.new arg.connection, output: (@dump_to || arg.logger.not_nil!.io), read: @read, write: @write
      end
    end

    macro new_hexdump(dump_to = nil, read = true, write = false)
      ::Bridge::Injector::Hexdump(Serializer).new({{dump_to}}, {{read}}, {{write}})
    end

    macro config_hexdump(*args, **opt)
      nil
    end
  end
end
