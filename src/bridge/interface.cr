require "colorize"

module Bridge
  record InterfaceArgument(Host), obj : Host, connection : IO, path_arguments : Array(String)? = nil

  # replace with InterfaceProc(Host) = Proc(InterfaceArgument(Host), Nil)

  module Host
    macro included
      # relative path => symbol of the method (without `api_` prefix)
      Interfaces = {} of String => Array(Symbol)
      alias InterfaceArgument = Bridge::InterfaceArgument({{@type}})
      alias InterfaceProc = Proc(InterfaceArgument, Nil)
      InterfaceProcs = {} of String => InterfaceProc
    end

    macro serialize_from_IO(type, io)
      {{type}}.from_msgpack {{io}}
    end

    macro serialize_to_IO(object, io)
      {{object}}.to_msgpack {{io}}
    end

    macro alias_api(path, to)
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

    macro api(define)
      {{define}}
      {%
        path = define.name.stringify
        methods = [("api_" + define.name.stringify).id.symbolize]
      %}
      add_interface {{path}}, {{methods}}
      def api_{{define.name}}(connection : IO)
        {% if define.args && define.args.size > 0 %}
          {% for arg in define.args %}
            {% raise "Argument #{arg} must indicates type in Bridge API" unless arg.restriction %}
            {% raise "Argument #{arg} doesn't support default value in Bridge API" if arg.default_value %}
          {% end %}
          {% if define.args.size == 1 %}
              respon = {{define.name}}(serialize_from_IO({{define.args.first.restriction}}, connection))
          {% else %}
           respon = {{define.name}}(*serialize_from_IO(Tuple({% for arg in define.args %}{{arg.restriction}},{% end %}), connection))
          {% end %}
        {% else %}
          respon = {{define.name}}
        {% end %}
        serialize_to_IO respon, connection
      end
      {{@type}}::InterfaceProcs[{{path}}] = generate_api_proc {{methods}}
    end

    macro append_all_interfaces_with_prefix(to, from, method, prefix)
        {%
          raise "#{from} not be resolved. Make sure it's a Bridge::Host." unless from = from.resolve
          raise "#{from}::Interfaces not be resolved. Make sure it's a Bridge::Host." unless from.constant :Interfaces
        %}
        {% for relative_path, methods in from.constant :Interfaces %}
        {%
          path = prefix + File::SEPARATOR + relative_path
          to = to.resolve
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
      {% else %}
        {% dirname = def_or_call %}
        class {{dirname.id.camelcase}}
          include ::Bridge::Host
          {{ yield }}
        end
        directory {{dirname.id}} : {{dirname.id.camelcase}}
      #  % raise "Syntax Error : invalid directory:\ndirectory #{def_or_call}" %}
      {% end %}
    end
  end
end
