module Bridge
  class BridgeFail < Exception
  end

  class InterfaceFail(Host, Driver) < BridgeFail
    # The multiplexed for most time.
    getter interface_path : String
    getter host : Host
    getter driver : Driver
    delegate host, to: @host

    def initialize(@host, @driver, @interface_path, msg, cause = nil)
      super "#{@driver} : #{msg}", cause
    end

    # def self.new(host, *args)
    #  ret = self(typeof(host)).allocate
    #  ret.initialize host, *args
    #  ret
    # end
  end

  macro bridge_fail(name, message)
    class {{name.id.camelcase}} < BridgeFail
      def initialize(cause = nil)
        super {{message}}, cause
      end
    end
  end

  macro interface_fail(name, message)
    class {{name.id.camelcase}}(Host, Driver) < InterfaceFail(Host, Driver)
      def initialize(host : Host, driver : Driver, interface_path, cause = nil)
        super host, driver, interface_path, {{message}}, cause
      end

      def initialize(host : String, driver : Driver, interface_path, cause = nil)
        super host, driver, interface_path, {{message}}, cause
      end
    end
  end

  interface_fail InterfaceNotFound, "API `#{interface_path}` not found in #{host}"
  interface_fail InterfaceBindFail, "Interface #{host}##{interface_path} fail to bind, because:\n#{cause.try &.message}"
  interface_fail InterfaceListenFail, "Interface #{host}##{interface_path} fail to listen, because:\n#{cause.try &.message}"
  interface_fail InterfaceExcuteFail, "Exception happend during execution of interface #{host}##{interface_path}#{cause ? ":\n\t#{cause.message}" : '.'}"
  interface_fail InterfaceTerminated, "Interface #{host}##{interface_path} has terminated, because: #{cause.try(&.message) || "no reason"}"
  interface_fail ConnectionTerminated, "Connection on interface #{host}##{interface_path} has terminated, because: #{cause.try(&.message) || "no reason"}"
  interface_fail ConnectionRetryTimeout, "Faild too many times."
  interface_fail IterfaceConnectFail, "Fail to connect interface #{host}##{interface_path}, because: #{cause.try &.message}"
  # Triggered when client receive an exception.
  interface_fail RecvException, "An exception received from #{host}##{interface_path}"
  interface_fail InterfaceClosed, "The interface #{host}#{interface_path} has been closed"

  class SomeFail(Fail, Driver) < Exception
    getter fails : Array(Fail)
    getter driver : Driver

    def initialize(@fails, @driver, cause = nil)
      super String.build { |str|
        str << "Some failures occured :\n"
        @fails.each { |f| str << f.message << '\n' }
      }, cause
    end

    def self.new(fails : Array(Fail), driver : Driver, cause = nil) forall Fail, Driver
      ret = SomeFail(Fail, Driver).allocate
      ret.initialize fails, driver, cause
      ret
    end
  end
end
