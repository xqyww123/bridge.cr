require "../spec_helper.cr"
require "../example_host.cr"

Bridge.def_server ZooTCPS,
  host: Zoo,
  driver: tcp_socket(
    domain: "127.0.0.1",
    port: 2235,
    family: :ipv4,
    sock_setting: ->(sock : ::Socket) {
      sock.setsockopt LibC::SO_REUSEADDR, 1
      nil
    },
    logger: LOGGER.dup,
    timeout: Time::Span.new(seconds: 1, nanoseconds: 0)
  ),
  serializer: msgpack(
    argument_as: hash,
    response_format: hash(
      data_field: ret,
      exception_field: err,
      exception_format: string
    )
  ),
  multiplex: send_path
Bridge.def_client ZooTCPC,
  interfaces: Zoo::Interfaces,
  client: tcp_socket(
    domain: "127.0.0.1",
    port: 2235,
    family: :ipv4,
    logger: LOGGER.dup,
    timeout: Time::Span.new(seconds: 1, nanoseconds: 0)
  ),
  serializer: msgpack(
    argument_as: hash,
    response_format: hash(
      data_field: ret,
      exception_field: err,
      exception_format: string
    )
  ),
  multiplex: send_path,
  injectors_everything: [
    hexdump(STDERR, write: true, read: true),
  ]

ZooTClient = ZooTCPC.new
ZooTServer = ZooTCPS.new ZooVar

describe Driver do
  describe Driver::TcpSocket do
    it "handle fail on connecting" do
      expect_raises(IterfaceConnectFail) do
        ZooTClient.zoo.should eq "cats and dogs are in the zoo"
      end
    end
    it "bind socket" do
      ZooTServer.bind
    end
    it "listen socket" do
      ZooTServer.listen
    end
    it "rpc" do
      ZooTClient.zoo.should eq "cats and dogs are in the zoo"
      3.times {
        ZooTClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      }
      expect_raises(IterfaceConnectFail) do
        # sleep time of 1.3 seconds exceeds reading timeout of the client
        # so an `IterfaceConnectFail` will be throwed.
        ZooTClient.lazy(1.3).should eq "Yes I'm lazy."
      end.cause.should be_a IO::Timeout
      # Since the last `IterfaceConnectFail`, the old socket will be closed,
      # and a new socket will be connected for the next request.
      ZooTClient.pet.cat("fish with gold").should eq "fish with gold was delicious"
      # After 1.5 seconds, two things will happeen.
      # 1. The last `lazy` call returns, but the connection has been closed by client,
      #    `Broken pipe` will be print in server's log.
      sleep 1.5
      # 2. 1.5 seconds is too long for server to keep the connection, yet another
      #    `Broken pipe` throwed in client's next request
      #     and then a new one should be connected.
      expect_raises(RecvException) do
        ZooTClient.pet.cat "gold fish"
      end.cause.not_nil!.message.should eq "gold fish is not a fish!"
    end
    it "close" do
      ZooTServer.close
    end
  end
end
