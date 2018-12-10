module Bridge
  abstract class Multiplexer
    class SendPath(HostT, SerializerT) < Multiplexer::Unique(HostT, SerializerT)
      def multiplex(origin_interface : String, arg : InterfaceArgument(SerializerT)) : String
        arg.serialize arg.connection, origin_interface
        UNIQUE_INTERFACE
      end

      def select(multiplexed_interface : String, arg : InterfaceArgument(SerializerT)) : String
        arg.deserialize(arg.connection, String)
      end
    end

    macro new_send_path
      ::Bridge::Multiplexer::SendPath(HostInfo, Serializer).new
    end
  end
end
