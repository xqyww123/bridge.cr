require "./spec_helper"

alias Driver = Bridge::Driver
alias Interface = Bridge::Interface

describe Bridge do
  describe Interface do
    it "collects interfaces" do
      Dog::Interfaces.should eq({"pet" => [:api_pet]})
      Zoo::Interfaces.should eq({"dog/pet" => [:dog, :api_pet], "dog2/pet" => [:dog2, :api_pet], "cat/fish!" => [:cat, :"api_fish!"], "zoo" => [:api_zoo]})
    end
    it "interface procs" do
      Dog::InterfaceProcs.size.should eq 1
      dog = Dog.new
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
