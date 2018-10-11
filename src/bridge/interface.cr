require "colorize"

module Bridge
  # replace with InterfaceProc(Host) = Proc(InterfaceArgument(Host), Nil)

  module Host
    record InterfaceArgument(Host), obj : Host, connection : IO

    macro included
      # relative path => symbol of the method (without `api_` prefix)
      Interfaces = {} of String => Array(Symbol)
      alias InterfaceArgument = Bridge::Host::InterfaceArgument({{@type}})
      alias InterfaceProc = Proc(InterfaceArgument, Nil)
      InterfaceProcs = {} of String => InterfaceProc

      def self.interfaces
        Interfaces
      end

      def self.interface_procs
        InterfaceProcs
      end
    end

    macro serialize_from_IO(type, io)
      {{type}}.from_msgpack {{io}}
    end

    macro serialize_to_IO(object, io)
      {{object}}.to_msgpack {{io}}
    end

    macro alias_api(path, to)
      {%
        to = to.stringify unless to.is_a? StringLiteral
        path = path.stringify unless path.is_a? StringLiteral
        interfaces = @type.constant(:Interfaces)
        interfaces[to] = interfaces[path]
      %}
      {{@type}}::InterfaceProcs[{{to}}] = {{@type}}::InterfaceProcs[{{path}}]
    end

    # macro alias_api(path, to)
    #  %path = File.join @@_bridge_current_directory + [{{to.id.stringify}}]
    #  %old = File.join @@_bridge_current_directory + [{{path.id.stringify}}]
    #  raise "Interface with path #{%path} has already been defined" if {{@type}}::Interfaces.includes? %path
    #  {{@type}}::Interfaces[%path] = {{@type}}::Interfaces[%old]
    #  {{@type}}::InterfaceProcs[%path] = {{@type}}::InterfaceProcs[%old]
    # end

    macro add_interface(path, methods)
      {%
        raise "Interface with path #{path} has already been defined" if @type.constant(:Interfaces)[path]
        @type.constant(:Interfaces)[path] = methods
      %}
    end

    macro generate_api_proc(methods)
      ->(args : {{@type}}::InterfaceArgument) {
        args.obj{% for method in methods %}.{{method.id}}{% end %}(args.connection)
        nil
      }
    end

    macro def_api(define)
      {%
        name = define.name
        args = define.args
        path = name.stringify
        methods = [("api_" + name.stringify).id.symbolize]
      %}
      add_interface {{path}}, {{methods}}
      def api_{{name.id}}(connection : IO)
        {% if args && args.size > 0 %}
          {% for arg in args %}
            {% raise "Argument #{arg} must indicates type in Bridge API" unless arg.restriction %}
            {% raise "Argument #{arg} doesn't support default value in Bridge API" if arg.default_value %}
          {% end %}
          {% if args.size == 1 %}
            respon = {{name.id}}(serialize_from_IO({{args.first.restriction}}, connection))
          {% else %}
          respon = {{name.id}}(*serialize_from_IO(Tuple({% for arg in args %}{{arg.restriction}},{% end %}), connection))
          {% end %}
        {% else %}
          serialize_from_IO(Nil, connection)
          respon = {{name.id}}
        {% end %}
        p respon
        serialize_to_IO respon, connection
      end
      {{@type}}::InterfaceProcs[{{path}}] = generate_api_proc {{methods}}
    end

    macro api(define)
      {{define}}
      {% if define.name == "getter" || define.name == "property" %}
        {% for ele in define.args %}
          def_api(def {{ele.var}}
          end)
        {% end %}
      {% else %}
        def_api({{define}})
      {% end %}
    end

    macro append_all_interfaces_with_prefix(to, from, method, prefix)
        {%
          raise "#{from} not be resolved. Make sure it's a Bridge::Host." unless from = from.resolve
          raise "#{from}::Interfaces not be resolved. Make sure it's a Bridge::Host." unless from.constant :Interfaces
        %}
        {% for relative_path, methods in from.constant :Interfaces %}
        {%
          path = prefix + File::SEPARATOR + relative_path
          to = to.resolve if to.is_a? Path
          my_methods = [method.id.symbolize] + methods
        %}
        add_interface {{path}}, {{my_methods}}
        {{to}}::InterfaceProcs[{{path}}] = generate_api_proc {{my_methods}}
      {% end %}
    end

    # macro directory(dirname, &block)
    # end

    macro directory(def_or_call)
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
      {% elsif def_or_call.is_a? Call && def_or_call.block %}
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
  end
end
