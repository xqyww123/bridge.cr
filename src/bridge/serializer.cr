module Bridge
  # module Segments
  #  DATA  = :data
  #  ERROR = :error
  # end

  macro def_serializer(call, &block)
    (::Bridge::Serializer.def_{{call}} {{block}})
  end

  abstract class Serializer
    abstract def deserialize(io : IO, val_type)
    abstract def serialize(io : IO, val) : Nil
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
          def self.pack(serializer, io, respon, exception : Exception?)
            serializer.serialize io, { {{data_field.id.symbolize}} => respon, {{exception_field.id.symbolize}} => ExceptionFormat.pack(exception) }
          end
          def self.unpack(serializer, io, response_format_type)
            pack = serializer.deserialize io, response_format_type
            { pack[{{data_field.id.symbolize}}], ExceptionFormat.unpack(pack[{{exception_field.id.symbolize}}]) }
          end
          macro type(respon_type)
            NamedTuple({{data_field.id.stringify}}: \{{respon_type}} | Nil, {{exception_field.id.stringify}}: ExceptionFormat::Type)
          end
        end
        module Config
          RESPONSE = {_name_: "hash", data_field: {{data_field.id.stringify}},
            exception_field: {{exception_field.id.stringify}},
            exception_format: Config::EXCEPTION}
        end
        {{yield}}
      end
      end

      macro def_bool(exception_format = :string)
        ::Bridge::Serializer::ExceptionFormat.def_{{exception_format.id}} do
          module ResponseFormat
            def self.pack(serializer, io, respon, exception : Exception?)
              if exception
                serializer.serialize io, false
                serializer.serialize io, exception
              else
                serializer.serialize io, true
                serializer.serialize io, respon
              end
            end
            macro type(respon_type)
              \{{respon_type}}
            end
            def self.unpack(serializer, io, response_format_type)
              if serializer.deserialize io, Bool
                {serializer.deserialize(io, response_format_type), nil}
              else
                {nil, ExceptionFormat.unpack serializer.deserialize(io, ExceptionFormat::Type)}
              end
            end
          end
          module Config
            RESPONSE = {_name_: "bool", exception_format: EXCEPTION}
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
        module Config
          EXCEPTION = {_name_: "string"}
        end
        {{yield}}
      end
    end
  end
end

require "./serializers/*"
