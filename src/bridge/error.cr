module Bridge
  class InterfaceFail(Host) < Exception
    getter relative_path : String
    getter host : Host

    def initialize(@host, @relative_path, msg, cause = nil)
      super msg, cause
    end
  end

  macro interface_fail(name, message)
    class {{name.camelcase}}(Host) < InterfaceFail(Host)
      def initialize(host, relative_path, cause = nil)
        super host, relative_path, {{message}}, cause
      end
    end
  end

  interface_fail InterfaceNotFound, "API `#{relative_path}` not found in #{Host} #{host}"
  interface_fail InterfaceBindFail, "Interface #{relative_path} in #{Host} fail to bind, because:\n#{cause.message}"
  interface_fail InterfaceListenFail, "Interface #{relative_path} in #{Host} fail to listen, because:\n#{cause.message}"

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
