require "../../src/bridge.cr"
require "msgpack"

# First, design `Host`s with its API.
class Dog
  include Bridge::Host

  def initialize(@name)
  end

  api getter name : String
end

class Zoo
  include Bridge::Host

  directory getter dog : Dog

  def initialize(@dog)
  end

  GENDER = {"male" => "gentle", "female" => "lady"}
  api def welcome(guest : String, gender : String)
    "Welcome #{GENDER[gender]?} #{guest}!"
  end
end

# Second, create an instance of the Host

dog = Dog.new "Donald"
zoo = Zoo.new dog

# At last, start a server and run.

server = Bridge::Driver::UnixSocket.new zoo, "/tmp/socks_folder"
server.listen

Fiber.yield
exit if gets

# interface is collected automatically
p Zoo::InterfaceProcs
# => { "welcome" => #<Proc(InterfaceArgument, Nil) ...>,
# "dog/name" => #<Proc(InterfaceArgument, Nil) ... > }

#
