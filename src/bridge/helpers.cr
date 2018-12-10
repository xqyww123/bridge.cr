module Bridge
  module Helpers
    module Mixin
      {% for level in [:debug, :info, :warn, :error, :fatal] %}
      def log_{{level.id}}(excep : Exception, progname = nil)
        logger.{{level.id}} excep.message, progname: progname
        excep
      end
      def log_{{level.id}}(message, progname = nil)
        message = message.message if message.is_a? Exception
        logger.{{level.id}} message, progname: progname
      end
      {% end %}
    end
  end
end
