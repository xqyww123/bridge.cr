require "yaml"
require "../src/bridge"
require "./spec_helper.cr"

class Dog
  include Bridge::Host

  def initialize(@name)
  end

  api def pet(arg1 : Int32, arg2 : String) : String
    arg1.to_s + arg2
  end

  api getter name : String
end

class Zoo
  include Bridge::Host

  def initialize(@dog, @dog2, @cat)
  end

  @dog : Dog

  directory def dog : Dog
    @dog
  end

  directory dog2 : Dog

  # create a new `Cat` class with the content of the block,
  # with a `getter cat : Cat`
  directory cat do
    api def fish!(fish : String) : String
      raise "#{fish} is not a fish!" unless fish.starts_with? "fish "
      "#{fish} was delicious"
    end
    alias_api fish!, to: pet
  end

  api def zoo : String
    "cats and dogs are in the zoo"
  end

  api def lazy(lazy_time : Float32) : String
    sleep lazy_time
    "Yes I'm lazy."
  end

  alias_api "dog/pet", to: "pet_dog"
  alias_api "cat/pet", to: "pet/cat"

  # Every `Bridge::Host` has two constant : Interface & InterfaceProcs
  # Interfaces is a Hash from interface name (the path of the interface, as a String) to the path of the calling chain.
  # Every api will generate a wrapper method called `api_<method name>`, which parse argument from IO and then serialize the result of the method into IO, with only one argument of IO type and Nil return.
  # Here, `api_name` is the wrapper of the method `name`.
  puts "Zoo's api : #{Interfaces.to_yaml}" # => {"dog/pet" => [:dog, :api_pet], "dog/name" => [:dog, :api_name], "zoo" => [:api_zoo], ...}
  # InterfaceProcs is a Hash from interface name to the Proc calling the chain
  # puts "Zoo's api : #{APIs::InterfaceProcs}" # => {"dog/pet" => #<Proc(Bridge::InterfaceArgument(Zoo), Nil):0x47a580>, ...}
end

ZooVar = Zoo.new Dog.new("alice"), Dog.new("bob"), Zoo::Cat.new

BasePath = File.tempname "bridge.cr-zoo", ""
LOGGER   = Logger.new STDERR, level: Logger::Severity::DEBUG
Bridge.def_server ZooUNIX,
  host: Zoo,
  driver: unix_socket(
    base_path: BasePath,
    logger: LOGGER.dup,
    timeout: Time::Span.new(seconds: 0, nanoseconds: 100_000_000)
  ),
  serializer: msgpack(
    argument_as: hash,
    response_format: hash(
      data_field: ret,
      exception_field: err,
      exception_format: string
    )
  ),
  multiplex: no
Bridge.def_client ZooUNIXClient,
  interfaces: Zoo::Interfaces,
  client: unix_socket(
    base_path: BasePath,
    logger: LOGGER.dup
  ),
  serializer: msgpack(
    argument_as: hash,
    response_format: hash(
      data_field: ret,
      exception_field: err,
      exception_format: string
    )
  ),
  multiplex: no,
  injectors_everything: [
    hexdump(STDERR, write: true, read: true),
  ]
