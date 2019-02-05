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
  api def welcome(guest : String, gender : String) : String
    "Welcome #{GENDER[gender]?} #{guest}!"
  end
end

# Second, create an instance of the Host

dog = Dog.new "Donald"
zoo = Zoo.new dog

# Third, define the server, including protocal and serialization format.

LOGGER = Logger.new STDERR, level: Logger::Severity::DEBUG
Bridge.def_server ZooUNIX,
  host: Zoo,
  driver: unix_socket(
    base_path: "/tmp/socks_folder",
    logger: LOGGER
  ),
  serializer: msgpack,
  multiplex: send_path
# The default format of msgpack serializer is `{ret: <ret val obj>, err: "exception's message or null"}`
# The format could be specified in limited freedom. And the `bridge` framework is an easy one with good performance, at price of limited flexibility, especially in format of serialization.

# At last, run the sever.

server = ZooUNIX.new zoo
server.bind
server.listen

Fiber.yield
exit if gets
