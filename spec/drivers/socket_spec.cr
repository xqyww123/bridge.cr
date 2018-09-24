require "../spec_helper.cr"

alias UnixSocket = Bridge::Driver::UnixSocket

BasePath  = Tempfile.tempdir "bridge.cr-zoo"
ZooServer = Bridge::Driver::UnixSocket.new ZooVar, BasePath

describe Driver do
  describe UnixSocket do
    it "bind socket" do
      ZooServer.bind
    end
    it "listen socket" do
      ZooServer.listen
      Fiber.yield
      sock = ZooServer.client "zoo"
      3.times {
        nil.to_msgpack sock
        sock.flush
        String.from_msgpack(sock).should eq "cats and dogs are in the zoo"
      }
      sock.close
      sock = ZooServer.client "pet/cat"
      "gold fish".to_msgpack sock
      sock.flush
      String.from_msgpack(sock).should eq "gold fish was delicious"
      sock.close
      Fiber.yield
    end
  end
end
