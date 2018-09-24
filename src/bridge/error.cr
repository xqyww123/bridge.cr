module Bridge
  class BridgeFail < Exception
  end

  class InterfaceFail(Host) < BridgeFail
    getter interface_path : String
    getter host : Host

    def initialize(@host, @interface_path, msg, cause = nil)
      super msg, cause
    end

    def self.new(host, *args)
      ret = self(typeof(host)).allocate
      ret.initialize host, *args
      ret
    end
  end

  macro bridge_fail(name, message)
    class {{name.id.camelcase}} < BridgeFail
      def initialize(cause = nil)
        super {{message}}, cause
      end
    end
  end

  macro interface_fail(name, message, &block)
    class {{name.id.camelcase}}(Host) < InterfaceFail(Host)
      def initialize(host : Host, interface_path, cause = nil)
        super host, interface_path, {{message}}, cause
      end
      {{ yield }}
    end
  end

  interface_fail InterfaceNotFound, "API `#{interface_path}` not found in #{Host} #{host}"
  interface_fail InterfaceBindFail, "Interface #{interface_path} in #{Host} fail to bind, because:\n#{cause.message}"
  interface_fail InterfaceListenFail, "Interface #{interface_path} in #{Host} fail to listen, because:\n#{cause.message}"

  class DriverRunningFail(Host, Driver) < InterfaceFail(Host)
    getter driver : Driver

    def initialize(host, @driver, interface_path, msg, cause = nil)
      super host, interface_path, "Exception occured for #{Driver} #{@driver} on #{Host} #{host}:\n#{msg}"
    end

    def self.new(host, driver, *args)
      ret = self(typeof(host), typeof(driver)).allocate
      ret.initialize host, driver, *args
      ret
    end
  end

  macro driver_running_fail(name, msg)
    class {{name.id.camelcase}}(Host, Driver) < DriverRunningFail(Host, Driver)
      def initialize(host : Host, driver : Driver, interface_path, cause = nil)
        super host, driver, interface_path, {{msg}}, cause
      end
    end
  end

  driver_running_fail InterfaceExcuteFail, "Exception happend during execution of interface #{interface_path}#{cause ? ":\n\t#{cause.message}" : '.'}"

  class SomeFail(Fail) < Exception
    getter fails : Array(Fail)

    def initialize(@fails, cause = nil)
      super String.build { |str|
        str << "Some failures occured :\n"
        @fails.each { |f| str << f.message << '\n' }
      }, cause
    end

    def self.new(fails : Array(Fail)) forall Fail
      ret = SomeFail(Fail).allocate
      ret.initialize fails
      ret
    end
  end
end
