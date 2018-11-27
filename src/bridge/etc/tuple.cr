def NamedTuple.types_as_type
  {% begin %}
    Tuple({% for k, type in T %} {{type}}, {% end %} )
  {% end %}
end

def Nil.types_as_type
  Nil
end

def NamedTuple.replace_values(values)
  {% begin %}
  {% ind = 0 %}
    {
      {% for k, v in T %}
        {{k}} => values[{{ind}}],
        {% ind += 1 %}
      {% end %}
    }
  {% end %}
end

def Nil.replace_values(value : Nil)
  value
end
