module Bridge
  module Segments
    DATA  = :data
    ERROR = :error
  end

  macro def_serializer(name, type = :msgpack, *args, **options, &block)
    ::Bridge::Serializer::{{type.id.camelcase}}.define {{name}}, {{*args}} {{ ",".id unless args.empty? }} {{**options}} {{block}}
  end

  macro def_format(name, type = :free, *args, **options, &block)
    ::Bridge::Serializer::ResponseFormat.generate_{{type.id}} {{name}}, {{*args}} {{ ",".id unless args.empty? }} {{**options}} {{block}}
  end

  abstract class Serializer
    abstract def deserialize(io : IO, val)
    abstract def serialize(io : IO, val_type) : Nil
    abstract def deserialize_request(io : IO, argument_type : T) forall T
    abstract def serialize_respon(io : IO, response, exception = nil) : Nil

    module ResponseFormat
      # struct Hash
      #  getter data_field_name : String
      #  getter exception_field_name : String

      #  def initialize(@data_field_name, @exception_field_name)
      #  end

      #  def pack(respon, exception)
      #    {@data_field_name => respon, @exception_field_name => exception}
      #  end
      # end

      macro generate_hash(name, data_field, exception_field)
        module {{name.id.camelcase}}
          def self.pack(respon, exception)
              { {{data_field.id.symbolize}} => respon, {{exception_field.id.symbolize}} => exception }
          end
        end
      end
    end
  end
end

require "./serializers/*"
