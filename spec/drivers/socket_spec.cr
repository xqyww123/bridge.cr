require "../spec_helper.cr"

alias UnixSocket = Bridge::Driver::UnixSocket

ZooClient = ZooUNIXClient.new
ZooServer = ZooUNIX.new ZooVar

describe Driver do
  describe UnixSocket do
    it "bind socket" do
      ZooServer.bind
    end
    it "listen socket" do
      ZooServer.listen
    end
    it "rpc" do
      3.times {
        ZooClient.zoo.should eq "cats and dogs are in the zoo"
      }
      ZooClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      expect_raises(RecvException) do
        ZooClient.pet.cat "gold fish"
      end.cause.not_nil!.message.should eq "gold fish is not a fish!"
    end
  end
end
describe Client do
  describe UnixSocket do
    # it "raise error if interface not exists" do
    #  expect_raises(IterfaceConnectFail) do
    #    ZooClient.pet.cat2("gold fish").should eq "gold fish was delicious"
    #  end
    # end
  end
end
