Bridge
===

A general purposed, cross-protocol and cross-serialization RPC framework, designed for easiness, simpleness and performance.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  bridge:
    github: xqyww123/bridge.cr
```

## Usage

Define API and the Protocol to communicate.

```crystal
require "bridge"
# Msgpack is the default serialization protocol
require "msgpack"

# APIs are defined as the rubyist way.
class Dog
  include Bridge::Host

  def initialize(@name)
  end

  api getter name : String
end

class Zoo
  include Bridge::Host

  directory getter dog : Dog
  # A directory is a getter or any method returns Host.
  # It maps path "path/to/api" to interface `path.to.api`.
  # Currently path with arguments like "book/:id/get" isn't supported, but it's on the plan.

  def initialize(@dog)
  end

  GENDER = {"male" => "gentle", "female" => "lady"}
  api def welcome(guest : String, gender : String)
    "Welcome #{GENDER[gender]?} #{guest}!"
  end
end

# Create the instance of Host and start the server.
dog = Dog.new "Donald"
zoo = Zoo.new dog
server = Bridge::Driver::UnixSocket.new zoo, "/tmp/socks_folder"
server.listen

exit if gets
```

`UnixServer` listens on following files under Msgpack protocol by default.

```
/tmp/socks_folder/welcome
/tmp/socks_folder/dog/name
```

Then, call the API in other programs and other languages. Illustrate using Ruby:

``` ruby
require 'msgpack'
require 'socket'

s = UNIXSocket.new("/tmp/socks_folder/welcome")
["Ruby", "female"].to_msgpack s; s.flush
u = MessagePack::Unpacker.new s
puts u.unpack

["Ruby, and the channel is usable", "female"].to_msgpack s; s.flush
puts u.unpack

s2 = UNIXSocket.new("/tmp/socks_folder/dog/name")
# the way to call a method without arguments is just to send nil.
nil.to_msgpack s2; s2.flush
u2 = MessagePack::Unpacker.new s2
puts "Name of the dog is #{u2.unpack}"
```

You can run the code on your computer. They locate in [spec/example/simple.cr & spec/example/simple.rb](https://github.com/xqyww123/bridge.cr/tree/master/spec/example/).

### Detail

Bridge consists two parts : `Host` & `Driver`.

#### Host

`Host` maintains two constants `Interfaces` and `InterfaceProcs`. It also provides class methods `interfaces` and `interface_procs` to acquire those two constants.

Macro `API` accepts a method definition or many other forms, see [an example with more detail](). `API` wraps the method with a new one having the `api_` prefix, and register information into `Interfaces` & `InterfaceProc`.

The wrapper has form `def api_APINAME(connection : IO) : Nil`, and it reads arguments from IO and serializes responses back into IO. See [Serialization](https://github.com/xqyww123/bridge.cr/wiki/Serialization) for more details. For example, `api def xxx` will generate a method `api_xxx(connection : IO)` calling `xxx`.

`Interfaces` is a `Hash(String, Array(Symbol))` mapping interface path to calling chain. For example, calling chain of interface "path/to/api_xxx" is exactly `[:path, :to, :api_xxx]`.

`InterfaceProcs` is a `Hash(String, Proc(InterfaceArgument(Host), Nil))` mapping interface path to a Proc calling the wrapper following the calling chain. 
Struct `InterfaceArgument` only have two fields currently: `obj : Host` and `connection : IO`.
For example, the Proc of "path/to/api_xxx" is `(InterfaceArgument(Host), Nil)->{|arg| arg.obj.path.to.api_xxx arg.connection }`.

#### Driver

According to those two constants of any given Host, Driver listens and waits for requests, manages connections, figures out which interface to call, and triggers the call finally.

Different Driver could be implemented on different protocols or framework.
Like `UnixSocket` binds sockets for each interface following the directory structure, or all in one socket with multiplex depending on configure.

In this example, the `UnixSocket` listens on following sockets:

```
/tmp/socks_folder/welcome
/tmp/socks_folder/dog/name
```

By default, `UnixSocket` opens as many sockets as interfaces following the directory structure, because of lacking a standard way for the multiplex.

Currently, the only default behaviour of `UnixSocket` implemented but any other Drivers.

## Contributing

Contributions are highly welcome, especially on Drivers.

1. Fork it (<https://github.com/xqyww123/bridge/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [xqyww123](https://github.com/xqyww123) Shirotsu Essential - creator, maintainer

