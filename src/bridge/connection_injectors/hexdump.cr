require "io/hexdump"

module Bridge
  module Injector
    class Hexdump(SerializerT) < Everything(SerializerT)
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
  end
end
