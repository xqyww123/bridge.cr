module Bridge
  class BridgeFail < Exception
  end

  class InterfaceFail(Host) < BridgeFail
    getter interfac_path : String
    getter host : Host

    def initialize(@host, @interfac_path, msg, cause = nil)
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
      def initialize(host, interfac_path, cause = nil)
        super host, interfac_path, {{message}}, cause
      end
      {{ yield }}
    end
  end

  interface_fail InterfaceNotFound, "API `#{interfac_path}` not found in #{Host} #{host}"
  interface_fail InterfaceBindFail, "Interface #{interfac_path} in #{Host} fail to bind, because:\n#{cause.message}"
  interface_fail InterfaceListenFail, "Interface #{interfac_path} in #{Host} fail to listen, because:\n#{cause.message}"

  class DriverRunningFail(Host, Driver) < InterfaceFail(Host)
    getter driver : Driver

    def initialize(host, @driver, interfac_path, msg, cause = nil)
      super host, interfac_path, "Exception occured for #{Driver} #{@driver} on #{Host} #{host}:\n#{msg}"
    end

    def self.new(host, driver, *args)
      ret = self(typeof(host), typeof(driver)).allocate
      ret.initialize host, driver, *args
      ret
    end
  end

  macro driver_running_fail(name, msg)
    class {{name.id.camelcase}}(Host, Driver) < DriverRunningFail(Host, Driver)
      def initialize(host, driver, interfac_path, cause = nil)
        super host, driver, interfac_path, {{msg}}, cause
      end
    end
  end

  driver_running_fail InterfaceExcuteFail, "Exception happend during execution of interface #{interface}#{cause ? ":\n\t#{cause.message}" : '.'}"

  class SomeFail(Fail) < Exception
    getter fails : Array(Fail)

    def initialize(@fails, cause = nil)
      super String.build { |str|
        str << "Some failures occured :\n"
        @fails.each { |f| str << f.message << '\n' }
      }, cause
    end

    def self.new(fails : Array(Fail)) forall Fail
      ret = self(Fail).allocate
      ret.initialize fails
      ret
    end
  end
end
