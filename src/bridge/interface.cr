require "colorize"
require "./serializer.cr"

module Bridge
  # Information of APIs, a hash from interface path to information table, where `path` is the method chain to the destination interface (path thought directories), `sig` is the signature of the calling.
  alias ApiInfo = Hash(String, NamedTuple(path: Array(Symbol), sig: NamedTuple(args: Hash(Symbol, String), ret: String)))

  # The direction may be useful in injectors or multiplexers.
  enum InterfaceDirection
    # The interface locates in the client, and connects to the server.
    ToServer,
    # The interface locates in the server, opened from client.
    FromClient
  end
  # All parameters required to call an interface.
  record InterfaceArgument(SerializerT), serializer : SerializerT, connection : IO, logger : Logger?, direction : InterfaceDirection do
    include Helpers::Mixin

    delegate serialize, serialize_respon, deserialize, deserialize_request, to: @serializer

    def wrap(connection : IO = @connection, logger : Logger = @logger)
      InterfaceArgument(SerializerT).new @serializer, connection, logger, @direction
    end
  end

  # Once included, `Interfaces : ApiInfo` will be created where stores the api information, and several macro and methods will be defined to help build the Host including:
  # - `.interfaces` : returns the `Interface` constant. It's convinient when the Host is a generic.
  module Host
    macro included
      {% unless @type.has_constant? :Interfaces %}
      # All api information of the Host
      Interfaces = {} of String => {path: Array(Symbol), sig: {args: Hash(Symbol, String), ret: String}}


      def self.interfaces
        Interfaces
      end
      {% end %}
    end

    # macro serialize_from_IO(type, io)
    #  {{type}}.from_msgpack {{io}}
    # end

    # macro serialize_to_IO(object, io)
    #  {{object}}.to_msgpack {{io}}
    # end

    macro alias_api(path, to)
     {%
       to = to.stringify unless to.is_a? StringLiteral
       path = path.stringify unless path.is_a? StringLiteral
       interfaces = @type.constant(:Interfaces)
       interfaces[to] = interfaces[path]
     %}
    end

    # macro alias_api(path, to)
    #  %path = File.join @@_bridge_current_directory + [{{to.id.stringify}}]
    #  %old = File.join @@_bridge_current_directory + [{{path.id.stringify}}]
    #  raise "Interface with path #{%path} has already been defined" if {{@type}}::Interfaces.includes? %path
    #  {{@type}}::Interfaces[%path] = {{@type}}::Interfaces[%old]
    #  {{@type}}::InterfaceProcs[%path] = {{@type}}::InterfaceProcs[%old]
    # end

    macro add_interface(path, info)
      {%
        raise "Interface with path #{path} has already been defined" if @type.constant(:Interfaces)[path]
        @type.constant(:Interfaces)[path] = info
      %}
    end

    macro def_api(define)
      {%
        name = define.name
        args = define.args
        args = [] of Symbol unless args
        path = name.stringify
        methods = [name.id.symbolize]
        if rec = define.receiver
          raise "can only define api of receiver `self`" unless rec.stringify == "self"
          path = @type.stringify.gsub(/::/, "/") + "/" + path
          methods.unshift @type.symbolize
        end
      %}
      {% raise "Return type is necessary for Bridge API." unless define.return_type %}
      {% for arg in args %}
        {% raise "Argument #{arg} must indicate type, in Bridge API" unless arg.restriction %}
        {% raise "Argument #{arg} doesn't support default value in Bridge API" if arg.default_value %}
      {% end %}
      add_interface {{path}}, {path: {{methods}}, sig: {args: ({
        {% for arg in args %}
            {{arg.name.symbolize}} => {{arg.restriction.stringify}},
        {% end %}
      } of Symbol => String), ret: {{define.return_type.stringify}} } }
      def {{ "#{rec}.".id if rec }}{{name.id}}(arg : ::Bridge::InterfaceArgument(SerializerT)) : Nil forall SerializerT
        {% begin %}
        {% if args && args.size > 0 %}
          request = arg.serializer.deserialize_request arg.connection, NamedTuple(
          {% for arg in args %}
            {{arg.name.stringify}}: {{arg.restriction}},
          {% end %}
          )
          arg.log_debug "new execution on #{self}:{{name.id}}."
          respon = begin
          {{name.id}}(
          {% for arg in args %}
              {{arg.name.stringify}}: request[{{arg.name.symbolize}}],
          {% end %}
          )
        {% else %}
          arg.serializer.deserialize_request arg.connection
          respon = begin
          arg.log_debug "new execution on #{self}:{{name.id}}."
          {{name.id}}
        {% end %}
        rescue err
          arg.serializer.serialize_respon arg.connection, nil, err
          return
        end
        arg.serializer.serialize_respon arg.connection, respon
        {% end %}
      end
    end

    macro api(define)
      {{define}}
      {% if define.name == "getter" || define.name == "property" %}
        {% for ele in define.args %}
          def_api(def {{ele.var}} : {{ele.type}}
          end)
        {% end %}
      {% elsif define.name == "initialize" %}
      def_api(def self.new({% for arg in define.args %}{{arg.name}} : {{arg.restriction}}, {% end %}) : {{define.return_type}}
      end)
      {% else %}
        def_api({{define}})
      {% end %}
    end

    macro append_all_interfaces_with_prefix(to, from, method, prefix)
      {%
        raise "#{from} not be resolved. Make sure it's a Bridge::Host." unless from = from.resolve
        raise "#{from}::Interfaces not be resolved. Make sure it's a Bridge::Host." unless from.constant :Interfaces
      %}
      {% for relative_path, info in from.constant :Interfaces %}
        {% unless relative_path.chars[0] == relative_path.capitalize.chars[0] %}
        {%
          path = prefix + "/" + relative_path
          to = to.resolve if to.is_a? Path
          my_methods = [method.id.symbolize] + info[:path]
        %}
        add_interface {{path}}, {path: {{my_methods}}, sig: {{info[:sig]}} }
        {% end %}
      {% end %}
    end

    # macro directory(dirname, &block)
    # end

    macro directory(def_or_call, &block)
      {% if def_or_call.is_a? Def %}
        {%
          raise "Return type of a Def in Bridge Directory must be indicated explicitly:\ndirectory #{def_or_call}" unless def_or_call.return_type
          prefix = def_or_call.name.stringify
        %}
        {{def_or_call}}
        append_all_interfaces_with_prefix {{@type}}, {{def_or_call.return_type}}, {{def_or_call.name}}, {{prefix}}
      {% elsif def_or_call.is_a? TypeDeclaration %}
        getter {{def_or_call}}
        append_all_interfaces_with_prefix {{@type}}, {{def_or_call.type}}, {{def_or_call.var}}, {{def_or_call.var.stringify}}
      {% elsif def_or_call.is_a? Assign %}
        {% raise "Type of Bridge Directory must be indicated explicily, try `directory #{def_or_call.target} : Type = #{def_or_call.value}`\ndirectory #{def_or_call}" %}
      {% elsif def_or_call.is_a? Call && !def_or_call.block && !block %}
        {% if def_or_call.name == "getter" || def_or_call.name == "property" %}
          {{def_or_call}}
          {% for arg in def_or_call.args %}
            append_all_interfaces_with_prefix {{@type}}, {{arg.type}}, {{arg.var}}, {{arg.var.stringify}}
          {% end %}
        {% else %}
          {% raise "Return type in Bridge Directory must be indicated explicitly:\ndirectory #{def_or_call}\nTry: directory #{def_or_call} : RETURN_TYPE" %}
        {% end %}
      {% else %}
        {% dirname = def_or_call %}
        struct {{dirname.id.camelcase}}
          include ::Bridge::Host
          {{ yield }}
        end
        directory {{dirname.id}} : {{dirname.id.camelcase}} = {{dirname.id.camelcase}}.new
      #  % raise "Syntax Error : invalid directory:\ndirectory #{def_or_call}" %}
      {% end %}
    end

    module APIs
      macro generate_api_proc(hostT, info)
        ->(host : {{hostT}}, args : InterfaceArgument) {
          {% if info[:path][0].chars[0] == info[:path][0].capitalize.chars[0] %}
          {% for method, ind in info[:path] %}{{ ".".id if ind > 0 }}{{method.id}}{% end %}(args)
          {% else %}
          host{% for method in info[:path] %}.{{method.id}}{% end %}(args)
          {% end %}
          nil
        }
      end
    end
  end

  macro bind_host(name, hostT, serializerT)
    {% hostT = hostT.resolve %}
    struct {{name}}
      include ::Bridge::Host::APIs
      alias InterfaceArgument = Bridge::InterfaceArgument({{serializerT}})
      alias InterfaceProc = Proc({{hostT}}, InterfaceArgument, Nil)
      InterfaceProcs = {
        {% for path, info in hostT.constant :Interfaces %}
          {{path}} => generate_api_proc({{hostT}}, {{info}}),
        {% end %}
      } of String => InterfaceProc

      getter host : {{hostT}}
      getter serializer : {{serializerT}}

      def initialize(@host, @serializer)
      end

      def self.interfaces
        {{hostT}}::Interfaces
      end

      def self.interface_procs
        InterfaceProcs
      end

      def make_interface_argument(connection : IO, log : Logger)
        Bridge::InterfaceArgument.new @serializer, connection, log, Bridge::InterfaceDirection::FromClient
      end
    end
  end
end
