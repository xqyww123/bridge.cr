require "../spec_helper.cr"

alias UnixSocket = Bridge::Driver::UnixSocket

BasePath  = Tempfile.tempdir "bridge.cr-zoo"
ZooServer = Bridge::Driver::UnixSocket.new ZooVar, BasePath
ZooClient = Bridge::Client::UnixSocket(Zoo).new BasePath

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
        ZooClient.rpc_call("zoo", String).should eq "cats and dogs are in the zoo"
      }
      ZooClient.rpc_call("pet/cat", String, "gold fish").should eq "gold fish was delicious"
    end
  end
end
describe Client do
  describe UnixSocket do
    it "raise error if interface not exists" do
      expect_raises(IterfaceConnectFail(Zoo)) do
        ZooClient.rpc_call("pet/cat2", String, "gold fish").should eq "gold fish was delicious"
      end
    end
  end
end
