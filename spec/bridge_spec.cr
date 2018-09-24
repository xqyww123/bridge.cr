require "./spec_helper"

describe Bridge do
  describe Host do
    it "collects interfaces" do
      Dog::Interfaces.should eq({"name" => [:api_name], "pet" => [:api_pet]})
      Zoo::Interfaces.should eq({"dog/pet" => [:dog, :api_pet], "dog/name" => [:dog, :api_name], "dog2/pet" => [:dog2, :api_pet], "dog2/name" => [:dog2, :api_name], "cat/fish!" => [:cat, :"api_fish!"], "cat/pet" => [:cat, :"api_fish!"], "zoo" => [:api_zoo], "pet_dog" => [:dog, :api_pet], "pet/cat" => [:cat, :"api_fish!"]})
    end
    it "interface procs" do
      Dog::InterfaceProcs.size.should eq 2
      dog = Dog.new "dog"
      data = IO::Memory.new
      origin = {12_i32, "345"}
      origin.to_msgpack data
      data.rewind
      respon = Tuple(Int32, String).from_msgpack data
      respon.should eq origin
      pos = data.pos
      data.rewind
      Dog::InterfaceProcs.first[1].call Dog::InterfaceArgument.new dog, data
      data.pos = pos
      respon = String.from_msgpack data
      respon.should eq "12345"
    end
  end
end
