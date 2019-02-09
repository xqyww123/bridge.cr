module Bridge
  abstract class Injector(SerializerT)
    macro add_injectors(who, injectors_everything, injectors_multiplex, injectors_calling)
      {% for injs_name, injs in {injectors_everything: injectors_everything, injectors_multiplex: injectors_multiplex, injectors_calling: injectors_calling} %}
        {% if injs && !injs.empty? %}
          {% for inj in injs %}
          {{who}}.{{injs_name.id}} << ::Bridge::Injector.new_{{inj}}
          {% end %}
        {% end %}
      {% end %}
    end

    macro config_injectors(injectors_everything, injectors_multiplex, injectors_calling)
      module Config
        {% if injectors_everything %}
        INJECTORS_EVERYTHING = [{% for inj in injectors_everything %}config_{{inj}},{% end %}].compact
        {% else %}
          INJECTORS_EVERYTHING = [] of Injector(Serializer)
        {% end %}
        {% if injectors_multiplex %}
          INJECTORS_MULTIPLEX = [{% for inj in injectors_multiplex %}config_{{inj}},{% end %}].compact
        {% else %}
          INJECTORS_MULTIPLEX = [] of Injector(Serializer)
        {% end %}
        {% if injectors_calling %}
          INJECTORS_CALLING = [{% for inj in injectors_calling %}config_{{inj}},{% end %}].compact
        {% else %}
          INJECTORS_CALLING = [] of Injector(Serializer)
        {% end %}
      end
    end

    # injector_multiplex : Apply the injection for multiplex only
    # injector_calling : Apply the injection for calling only
    # injector_everything : Apply the injection for everything, including multiplex and calling.

    abstract def inject(arg : InterfaceArgument(SerializerT)) : InterfaceArgument(SerializerT)
  end
end

require "./connection_injectors/*"
