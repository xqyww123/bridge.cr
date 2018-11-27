module Bridge
  module Injector
    # Apply the injection for multiplex only
    abstract class Multiplex(HostBinding)
      abstract def inject(arg : InterfaceArgument(HostBinding)) : InterfaceArgument(HostBinding)
    end

    # Apply the injection for calling only
    abstract class Calling(HostBinding)
      abstract def inject(arg : InterfaceArgument(HostBinding)) : InterfaceArgument(HostBinding)
    end

    # Apply the injection for everything, including multiplex and calling.
    abstract class Everything(HostBinding)
      abstract def inject(arg : InterfaceArgument(HostBinding)) : InterfaceArgument(HostBinding)
    end
  end
end
