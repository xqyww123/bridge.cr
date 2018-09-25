require "../src/bridge"

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
      "#{fish} was delicious"
    end
    alias_api fish!, to: pet
  end

  api def zoo
    "cats and dogs are in the zoo"
  end

  alias_api "dog/pet", to: "pet_dog"
  alias_api "cat/pet", to: "pet/cat"

  # Every `Bridge::Host` has two constant : Interface & InterfaceProcs
  # Interfaces is a Hash from interface name (the path of the interface, as a String) to the path of the calling chain.
  # Every api will generate a wrapper method called `api_<method name>`, which parse argument from IO and then serialize the result of the method into IO, with only one argument of IO type and Nil return.
  # Here, `api_name` is the wrapper of the method `name`.
  puts "Zoo's api : #{Interfaces}" # => {"dog/pet" => [:dog, :api_pet], "dog/name" => [:dog, :api_name], "zoo" => [:api_zoo], ...}
  # InterfaceProcs is a Hash from interface name to the Proc calling the chain
  puts "Zoo's api : #{InterfaceProcs}" # => {"dog/pet" => #<Proc(Bridge::InterfaceArgument(Zoo), Nil):0x47a580>, ...}
end

ZooVar = Zoo.new Dog.new("alice"), Dog.new("bob"), Zoo::Cat.new
