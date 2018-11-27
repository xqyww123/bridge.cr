require "./spec_helper"

describe Bridge do
  describe Host do
    it "collects interfaces" do
      Dog::Interfaces.should eq({"pet" => {path: [:api_pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "name" => {path: [:api_name], sig: {args: ({} of Symbol => String), ret: ""}}})
      Zoo::Interfaces.should eq({"dog/pet" => {path: [:dog, :api_pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "dog/name" => {path: [:dog, :api_name], sig: {args: ({} of Symbol => String), ret: ""}}, "dog2/pet" => {path: [:dog2, :api_pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "dog2/name" => {path: [:dog2, :api_name], sig: {args: ({} of Symbol => String), ret: ""}}, "cat/fish!" => {path: [:cat, :"api_fish!"], sig: {args: {:fish => "String"}, ret: "String"}}, "cat/pet" => {path: [:cat, :"api_fish!"], sig: {args: {:fish => "String"}, ret: "String"}}, "zoo" => {path: [:api_zoo], sig: {args: ({} of Symbol => String), ret: ""}}, "pet_dog" => {path: [:dog, :api_pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "pet/cat" => {path: [:cat, :"api_fish!"], sig: {args: {:fish => "String"}, ret: "String"}}})
    end
    it "interface procs" do
      DogAPIs::InterfaceProcs.size.should eq 2
      dog = Dog.new "dog"
      dog = DogAPIs.new dog, ZooSerializer.new
      data = IO::Memory.new
      origin = {arg1: 12_i32, arg2: "345"}
      origin.to_msgpack data
      pos = data.pos
      data.rewind
      DogAPIs::InterfaceProcs.first[1].call dog.make_interface_argument data
      data.pos = pos
      respon = NamedTuple(err: String?, ret: String).from_msgpack data
      respon[:ret].should eq "12345"
      respon[:err].should be nil
    end
  end
end
