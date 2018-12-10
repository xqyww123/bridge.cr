module Bridge
  macro def_client(name, *, interfaces, client, serializer, multiplex,
                   injectors_everything = nil,
                   injectors_multiplex = nil,
                   injectors_calling = nil)
    {% if interfaces.is_a? Path
         interfaces = interfaces.resolve
       end %}
    class {{name}}
      include ::Bridge::Mirror

      Interfaces = {{interfaces}}

      def self.interfaces
        Interfaces
      end

      alias HostInfo = self
      alias Client = ::Bridge::Client::{{client.id.camelcase}}

      def initialize(@client)
      end

      def self.new(client : Client)
        ret = allocate
        ret.initialize client
        ret
      end

      ::Bridge.def_serializer({{serializer}}) do
        getter client : Client(HostInfo, Serializer)

        def self.new(*args,
                    {% if multiplex != :dynamic %}
                       multiplexer = ::Bridge::Multiplexer.new_{{multiplex}},
                     {% else %}
                       multiplexer : ::Bridge::Multiplexer,
                     {% end %}
                     serializer : Serializer = Serializer.new
                    )
          client = Client(HostInfo, Serializer).new(*args,
            {% if client.is_a? Call && client.args %}
            {% for arg in client.args %}
              {{arg}},
            {% end %}
            {% end %}
            {% if client.is_a? Call && client.named_args %}
            {% for arg in client.named_args %}
              {{arg.name.stringify}}: {{arg.value}},
            {% end %}
            {% end %}
            serializer: serializer,
            multiplexer: multiplexer
            )
          Injector.add_injectors client, {{injectors_everything}}, {{injectors_multiplex}}, {{injectors_calling}}
          new client
        end

        {% for interface_path, info in interfaces %}
          def_interface({{interface_path}}, {{info}}, 0)
        {% end %}
      end
    end
  end

  module Mirror
    macro included
      SUBS = [] of Symbol
    end

    def to_s(io : IO)
      io << self.class
    end

    macro make_path(pathes)
      %<{% for path in pathes %}/{{path.id}}{% end %}>
    end

    macro def_interface(interface_path, info, ind)
      {% subs = @type.constant(:SUBS)
         if subs.is_a? Path
           subs = subs.resolve
         end
         pathes = interface_path.split "/"
         path = pathes[ind] %}
      {% if ind == pathes.size - 1 %}
        {% sig = info[:sig]
           args = sig[:args]
           if args.is_a? Expressions
             args = args.expressions.first
           end %}
        def {{path.id}}(
          {% for name, type in args %}
              {{name.id}} : {{type.id}},
          {% end %}
        )
          ret, err = @client.rpc {{interface_path}} do |io|
            @client.serializer.serialize_request(io,
              {% if args.empty? %}
                nil
              {% else %}
                {
                {% for name, type in args %}
                  {{name.id.stringify}}: {{name.id}},
                {% end %}
                }
              {% end %}
            )
            @client.serializer.deserialize_respon(io, ResponseFormat.type({{sig[:ret].id}}))
          end
          raise RecvException.new self, @client, {{interface_path}}, err if err
          ret.as {{sig[:ret].id}}
        end
      {% else %}
        struct {{path.id.camelcase}}
          {% unless subs.includes? path.id.symbolize %}
            include ::Bridge::Mirror
            getter client : Client(HostInfo, Serializer)
            def initialize(@client)
            end
            {% subs << path.id.symbolize %}
          {% end %}
          def_interface({{interface_path}}, {{info}}, {{ind + 1}})
        end
        def {{path.id}}
          {{path.id.camelcase}}.new @client
        end
      {% end %}
    end
  end
end
