module Bridge
  abstract class Multiplexer
    class SendPath(HostT, SerializerT) < Multiplexer::UniqueBase(HostT, SerializerT)
      def multiplex(origin_interface : String, arg : InterfaceArgument(SerializerT)) : String
        arg.serialize arg.connection, origin_interface
        UNIQUE_INTERFACE
      end

      def select(multiplexed_interface : String, arg : InterfaceArgument(SerializerT)) : String
        interface = Host.deserialize(arg.connection, String)
        raise InterfaceNotFound.new arg.host, self, interface unless @origins.includes? interface
        interface
      end
    end
  end
end
