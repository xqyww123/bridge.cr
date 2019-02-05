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
      ZooClient.zoo.should eq "cats and dogs are in the zoo"
      3.times {
        ZooClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      }
      expect_raises(RecvException) do
        ZooClient.pet.cat "gold fish"
      end.cause.not_nil!.message.should eq "gold fish is not a fish!"
    end
    it "rpc static method" do
      ZooUNIXClient::Zoo.static(ZooClient, 2).should eq 5
    end
    it "has timeout" do
      ZooClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      sleep 0.2
      ZooServer.connection_number.should eq 0
      ZooClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
    end
    it "can be killed" do
      ZooClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      ZooServer.kill_all
      Fiber.yield
      ZooServer.connection_number.should eq 0
    end
    # bug : if close before others, rpc to other servers seems be forwarded to this closed server.
    # I believe it's some fd reusing bug in crystal.
    # it "close" do
    #   ZooServer.close
    # end
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
