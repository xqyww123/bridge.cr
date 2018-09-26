require "logger"

module Bridge
  abstract class Client(Host)
    abstract def rpc_call(interface_path : String, &block : IO -> _) : Nil

    def rpc_call(interface_path : String, ret_type : Class)
      rpc_call(interface_path, ret_type, nil)
    end

    def rpc_call(interface_path : String, ret_type : Class, *args)
      args = args.first if args.size == 1
      rpc_call interface_path do |io|
        Host.serialize_to_IO(args, io)
        Host.serialize_from_IO(ret_type, io)
      end
    end
  end
end

require "./clients/*"