require "../spec_helper.cr"
require "../example_host.cr"

Bridge.def_server ZooTCPS,
  host: Zoo,
  driver: tcp_socket(
    server_domain: "127.0.0.1",
    port: 2235,
    family: :ipv4,
    sock_setting: ->(sock : ::Socket) {
      sock.setsockopt LibC::SO_REUSEADDR, 1
      nil
    },
    logger: LOGGER.dup,
    timeout: Time::Span.new(seconds: 30, nanoseconds: 0)
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
    server_domain: "127.0.0.1",
    port: 2235,
    family: :ipv4,
    logger: LOGGER.dup,
    timeout: Time::Span.new(seconds: 2, nanoseconds: 0)
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
      ZooTClient.lazy(30).should eq "Yes I'm lazy."
      expect_raises(RecvException) do
        ZooTClient.pet.cat "gold fish"
      end.cause.not_nil!.message.should eq "gold fish is not a fish!"
    end
    it "close" do
      ZooTServer.close
    end
  end
end
