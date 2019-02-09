module Bridge
  module Helpers
    module Mixin
      {% for level in [:debug, :info, :warn, :error, :fatal] %}
      def log_{{level.id}}(excep : Exception, progname = nil)
        if log = logger
          log.{{level.id}} excep.message, progname: progname
        end
        excep
      end
      def log_{{level.id}}(message, progname = nil)
        if log = logger
          log.{{level.id}} message, progname: progname
        end
      end
      {% end %}
    end
  end

  # :nodoc:
  macro expand_config(config_hash)
    {% if config_hash.is_a? NamedTupleLiteral %}
      {{config_hash[:_name_]}}({% for k, v in config_hash %}
        {% if k != :_name_ %}
          {{k}}: ::Bridge.expand_config({{v}})
        {% end %} {% end %})
    {% else %}
      {{config_hash}}
    {% end %}
  end
end
