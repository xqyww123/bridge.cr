class Logger
  getter io : IO
end

module Bridge
  module Helpers
    extend self

    def log_for(logger : Logger, progname : String)
      Logger.new logger.io, logger.level, logger.formatter, progname: progname
    end
  end
end
