require "spec"
require "../src/bridge"
require "msgpack"
require "tempfile.cr"

alias Driver = Bridge::Driver
alias Host = Bridge::Host

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

  directory cat do
    api def fish!(fish : String) : String
      "#{fish} was delicious"
    end
    alias_api fish!, to: pet
  end

  api def zoo
    "cats and dogs are in the zoo"
  end

  alias_api "dog/pet", to: "pet_dog"
  alias_api "cat/pet", to: "pet/cat"

  puts "Zoo's api : #{Interfaces}"
  puts "Zoo's api : #{InterfaceProcs}"
end

# api = TestAPI.new any_argument_your_class_require
# service = Bridge::Unix.new api, "/run/sockets"
# service.run

ZooVar = Zoo.new Dog.new("alice"), Dog.new("bob"), Zoo::Cat.new

class Tempfile
  def self.tempdir(extension) : String
    10.times do
      path = self.tempname extension
      begin
        Dir.mkdir_p path
      rescue err : Errno
        sleep 1
        next
      end
      return p path
    end
    raise "Fail to create tmp directory, try time out."
  end
end
