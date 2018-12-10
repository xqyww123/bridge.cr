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
end
