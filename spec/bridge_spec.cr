require "./spec_helper"

Bridge.bind_host(DogAPIs, Dog, ZooUNIX::Serializer)

describe Bridge do
  describe Host do
    it "collects interfaces" do
      Dog::Interfaces.should eq({"pet" => {path: [:pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "name" => {path: [:name], sig: {args: ({} of Symbol => String), ret: "String"}}})
      Zoo::Interfaces.should eq({"dog/pet" => {path: [:dog, :pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "dog/name" => {path: [:dog, :name], sig: {args: ({} of Symbol => String), ret: "String"}}, "dog2/pet" => {path: [:dog2, :pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "dog2/name" => {path: [:dog2, :name], sig: {args: ({} of Symbol => String), ret: "String"}}, "cat/fish!" => {path: [:cat, :"fish!"], sig: {args: {:fish => "String"}, ret: "String"}}, "cat/pet" => {path: [:cat, :"fish!"], sig: {args: {:fish => "String"}, ret: "String"}}, "zoo" => {path: [:zoo], sig: {args: ({} of Symbol => String), ret: "String"}}, "pet_dog" => {path: [:dog, :pet], sig: {args: {:arg1 => "Int32", :arg2 => "String"}, ret: "String"}}, "pet/cat" => {path: [:cat, :"fish!"], sig: {args: {:fish => "String"}, ret: "String"}}})
    end
    it "interface procs" do
      DogAPIs::InterfaceProcs.size.should eq 2
      dog = Dog.new "dog"
      dog = DogAPIs.new dog, ZooUNIX::Serializer.new
      data = IO::Memory.new
      origin = {arg1: 12_i32, arg2: "345"}
      origin.to_msgpack data
      pos = data.pos
      data.rewind
      DogAPIs::InterfaceProcs.first[1].call dog.host, dog.make_interface_argument data, LOGGER
      data.pos = pos
      respon = NamedTuple(err: String?, ret: String).from_msgpack data
      respon[:ret].should eq "12345"
      respon[:err].should be nil
    end
  end
end
