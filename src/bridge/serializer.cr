module Bridge
  module Segments
    DATA  = :data
    ERROR = :error
  end

  macro def_serializer(call, &block)
    (::Bridge::Serializer.def_{{call}} {{block}})
  end

  abstract class Serializer
    abstract def deserialize(io : IO, val)
    abstract def serialize(io : IO, val_type) : Nil
    abstract def deserialize_request(io : IO, request_Type : T) forall T
    # case of no argument
    abstract def deserialize_request(io : IO)
    abstract def deserialize_respon(io : IO, respon_type) : Tuple
    abstract def serialize_request(io : IO, request : NamedTuple?) : Nil
    abstract def serialize_respon(io : IO, response, exception : Exception? = nil) : Nil

    module ResponseFormat
      macro def_hash(data_field = "ret", exception_field = "err", exception_format = "string")
        ::Bridge::Serializer::ExceptionFormat.def_{{exception_format.id}} do
        module ResponseFormat
          def self.pack(respon, exception : Exception?)
            { {{data_field.id.symbolize}} => respon, {{exception_field.id.symbolize}} => ExceptionFormat.pack(exception) }
          end
          def self.unpack(pack)
            { pack[{{data_field.id.symbolize}}], ExceptionFormat.unpack(pack[{{exception_field.id.symbolize}}]) }
          end
          macro type(respon_type)
            NamedTuple({{data_field.id.stringify}}: \{{respon_type}} | Nil, {{exception_field.id.stringify}}: ExceptionFormat::Type)
          end
        end
        {{yield}}
      end
      end
    end

    module ExceptionFormat
      module AsString
        def self.pack(exception : Exception?) : String?
          exception.try &.message
        end

        def self.unpack(pack : String?) : Exception?
          pack.try { |pack| Exception.new pack }
        end

        alias Type = String?
      end

      macro def_string
        alias ExceptionFormat = ::Bridge::Serializer::ExceptionFormat::AsString
        {{yield}}
      end
    end
  end
end

require "./serializers/*"
