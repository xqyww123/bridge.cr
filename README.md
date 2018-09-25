Bridge
===

A general purposed, cross-protocol and cross-serialization RPC framework, designed for easiness, simpleness and perfromance.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  bridge:
    github: xqyww123/bridge
```

## Usage

Define API and the Protocol to communicate.

```crystal
require "bridge"
# Msgpack is the default serialization protocol
require "msgpack"

# API are defined as the rubyist way.
class Dog
  include Bridge::Host

  def initialize(@name)
  end

  api getter name : String
end

class Zoo
  include Bridge::Host

  directory getter dog : Dog
  # A directroy is a getter or any method returns Host
  # while "path/to/api" corresponds to `path.to.api`.
  # Currently path with argument like "book/:id/get" isn't supported, but it's on the plan.

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

Call the api in other program and other language. Illustrate using Ruby:

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

### Detail

Bridge consists two parts : `Host` & `Driver`.

#### Host

`Host` maintains two constants `Interfaces` and `InterfaceProcs`. It also provide class methods `interfaces` and `interface_procs` to accquire those two constants.

Macro `api` accepts a method definition or many other form, see [an example with more detail](). `api` wraps the method with a new one having the `api_` prefix, and register information into `Interfaces` & `InterfaceProc`.

The wrapper has form `def api_APINAME(connection : IO) : Nil`, and it reads arguments from IO and serializes respons back into IO. See [Serialization]() for more details. For example, `api def xxx` will generate a method `api_xxx(connection : IO)` calling `xxx`.

`Interfaces` is a `Hash(String, Array(Symbol))` mapping interface path to calling chain. For example, calling chain of interface "path/to/api_xxx" is exactly `[:path, :to, :api_xxx]`.

`InterfaceProcs` is a `Hash(String, Proc(InterfaceArgument(Host), Nil))` mapping interface path to a Proc calling the wrapper following the calling chain. 
Struct `InterfaceArgument` only have two fields currently: `obj : Host` and `connection : IO`.
For example, the Proc of "path/to/api_xxx" is `(InterfaceArgument(Host), Nil)->{|arg| arg.obj.path.to.api_xxx arg.connection }`.

#### Driver

According those two constant of any given Host, Driver listens and waits requests, manages connections, figures out which interface to call, and triggers the call finally.

Different Driver could implements on different protocal or framework.
Like `UnixSocket` binds sockets for each interfaces following the directory structure, or all in one socket with multiplex depeneding on configure.

In this example, the `UnixSocket` listens on following sockets:

```
/tmp/socks_folder/welcome
/tmp/socks_folder/dog/name
```

By default, `UnixSocket` opens as many sockets as interfaces following the directory structure, because of lacking a standard way for multiplex.

Currently, only default behaviour of `UnixSocket` implemented but any other Drivers.

## Contributing

Contribution is highly welcome, especially on Drivers.

1. Fork it (<https://github.com/xqyww123/bridge/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [xqyww123](https://github.com/xqyww123) Shirotsu Essential - creator, maintainer

