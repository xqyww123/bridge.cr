module Bridge
  abstract class Serializer
    macro def_msgpack(argument_as = :array, response_format = "hash")
      ::Bridge::Serializer::ResponseFormat.def_{{response_format.id}} do
        alias Serializer = ::Bridge::Serializer::Msgpack({{Msgpack::ARGUMENT_AS[argument_as.id.symbolize.underscore]}}, ResponseFormat)
        {{yield}}
      end
    end

    class Msgpack(ArgumentFormat, ResponseFormat) < Serializer
      def serialize(io : IO, val)
        val.to_msgpack io
      end

      def deserialize(io : IO, val_type)
        val_type.from_msgpack io
      end

      def deserialize_request(io : IO, argument_types)
        ArgumentFormat.deserialize_request io, argument_types
      end

      def deserialize_request(io : IO)
        ArgumentFormat.deserialize_request io
      end

      def deserialize_respon(io : IO, response_format_type)
        resp = response_format_type.from_msgpack io
        ResponseFormat.unpack resp
      end

      module ArgumentAsArray
        def self.deserialize_request(io : IO, argument_types)
          args = argument_types.types_as_type.from_msgpack io
          argument_types.replace_values args
        end

        def self.deserialize_request(io : IO)
          Array(String).from_msgpack io
        end

        def self.serialize_request(io : IO, request : NamedTuple) : Nil
          request.values.to_msgpack io
        end

        def self.serialize_request(io : IO)
          ([] of String).to_msgpack io
        end
      end

      module ArgumentAsHash
        def self.deserialize_request(io : IO, argument_types)
          argument_types.from_msgpack io
        end

        def self.deserialize_request(io : IO)
          Hash(String, String).from_msgpack io
        end

        def self.serialize_request(io : IO, request : NamedTuple) : Nil
          request.to_msgpack io
        end

        def self.serialize_request(io : IO)
          ({} of String => String).to_msgpack io
        end
      end

      ARGUMENT_AS = {array: ::Bridge::Serializer::Msgpack::ArgumentAsArray,
                     hash:  ::Bridge::Serializer::Msgpack::ArgumentAsHash}

      def serialize_respon(io : IO, respon, exception = nil)
        pack = ResponseFormat.pack respon, exception
        pack.to_msgpack io
      end

      def serialize_request(io : IO, request : Nil) : Nil
        ArgumentFormat.serialize_request io
      end

      def serialize_request(io : IO, request : NamedTuple) : Nil
        ArgumentFormat.serialize_request io, request
      end
    end
  end
end

class Exception
  def to_msgpack(io)
    message.to_msgpack io
  end
end
