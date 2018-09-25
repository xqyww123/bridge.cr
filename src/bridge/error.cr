module Bridge
  class BridgeFail < Exception
  end

  class InterfaceFail(Host) < BridgeFail
    getter interface_path : String
    getter host : Host
    getter driver : Driver(Host)

    def initialize(@host, @driver, @interface_path, msg, cause = nil)
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
      def initialize(host : Host, driver, interface_path, cause = nil)
        super host, driver, interface_path, {{message}}, cause
      end
      {{ yield }}
    end
  end

  interface_fail InterfaceNotFound, "API `#{interface_path}` not found in #{host}"
  interface_fail InterfaceBindFail, "Interface #{host}##{interface_path} fail to bind, because:\n#{cause.try &.message}"
  interface_fail InterfaceListenFail, "Interface #{host}##{interface_path} fail to listen, because:\n#{cause.try &.message}"
  interface_fail InterfaceExcuteFail, "Exception happend during execution of interface #{host}##{interface_path}#{cause ? ":\n\t#{cause.message}" : '.'}"
  interface_fail InterfaceTerminated, "Interface #{host}##{interface_path} has terminated, because: #{cause.try(&.message) || "no reason"}"
  interface_fail ConnectionTerminated, "Connection on interface #{host}##{interface_path} has terminated, because: #{cause.try(&.message) || "no reason"}"
  interface_fail ConnectionRetryTimeout, "Faild too many times."

  class SomeFail(Fail, Host) < Exception
    getter fails : Array(Fail)
    getter driver : Driver(Host)

    def initialize(@fails, @driver, cause = nil)
      super String.build { |str|
        str << "Some failures occured :\n"
        @fails.each { |f| str << f.message << '\n' }
      }, cause
    end

    def self.new(fails : Array(Fail), driver : Driver(Host), cause = nil) forall Fail, Host
      ret = SomeFail(Fail, Host).allocate
      ret.initialize fails, driver, cause
      ret
    end
  end
end
