module Bridge
  abstract class Serializer
    class Msgpack(ArgumentFormat, ResponseFormat) < Serializer
      macro define(name, argument_as, response_format)
        alias {{name}} = Bridge::Serializer::Msgpack({{ARGUMENT_AS[argument_as]}}, {{response_format}})
      end

      def serialize(io : IO, val)
        val.to_msgpack io
      end

      def deserialize(io : IO, val_type)
        val_type.from_msgpack io
      end

      def deserialize_request(io : IO, argument_types)
        ArgumentFormat.deserialize_request io, argument_types
      end

      module ArgumentAsArray
        def self.deserialize_request(io : IO, argument_types)
          args = argument_types.types_as_type.from_msgpack io
          argument_types.replace_values args
        end
      end

      module ArgumentAsHash
        def self.deserialize_request(io : IO, argument_types)
          argument_types.from_msgpack io
        end
      end

      ARGUMENT_AS = {array: ::Bridge::Serializer::Msgpack::ArgumentAsArray,
                     hash:  ::Bridge::Serializer::Msgpack::ArgumentAsHash}

      def serialize_respon(io : IO, respon, exception = nil)
        pack = ResponseFormat.pack respon, exception
        pack.to_msgpack io
      end
    end
  end
end

class Exception
  def to_msgpack(io)
    message.to_msgpack io
  end
end
