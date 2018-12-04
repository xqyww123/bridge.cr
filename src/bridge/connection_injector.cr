module Bridge
  module Injector
    macro add_injectors(who, injectors_everything, injectors_multiplex, injectors_calling)
      {% for injs_name, injs in {injectors_everything: injectors_everything, injectors_multiplex: injectors_multiplex, injectors_calling: injectors_calling} %}
        {% if injs && !injs.empty? %}
          {% for inj in injs %}
          {{who}}.{{injs_name.id}} << ::Bridge::Injector.new_{{inj}}
          {% end %}
        {% end %}
      {% end %}
    end

    # Apply the injection for multiplex only
    abstract class Multiplex(SerializerT)
      abstract def inject(arg : InterfaceArgument(SerializerT)) : InterfaceArgument(SerializerT)
    end

    # Apply the injection for calling only
    abstract class Calling(SerializerT)
      abstract def inject(arg : InterfaceArgument(SerializerT)) : InterfaceArgument(SerializerT)
    end

    # Apply the injection for everything, including multiplex and calling.
    abstract class Everything(SerializerT)
      abstract def inject(arg : InterfaceArgument(SerializerT)) : InterfaceArgument(SerializerT)
    end
  end
end

require "./connection_injectors/*"
