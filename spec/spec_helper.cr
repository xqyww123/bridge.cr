require "spec"
require "../src/bridge"
require "msgpack"

class Dog
  include Bridge::Host
  api def pet(arg1 : Int32, arg2 : String) : String
    arg1.to_s + arg2
  end

  puts "Dog's api : #{Interfaces}"
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
      "it was delicious"
    end
    alias_api fish!, to: pet
  end

  api def zoo
    "cats and dogs are in the zoo"
  end

  alias_api "dog/pet", to: "pet/dog"
  alias_api "cat/pet", to: "pet_cat"

  puts "Zoo's api : #{Interfaces}"
  puts "Zoo's api : #{InterfaceProcs}"
end

# api = TestAPI.new any_argument_your_class_require
# service = Bridge::Unix.new api, "/run/sockets"
# service.run
