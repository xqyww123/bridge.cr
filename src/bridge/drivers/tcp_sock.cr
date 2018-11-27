require "./socket.cr"

module Bridge
  abstract class Driver
    # class IPSocket(Host) < SocketDriver(Host, Socket::IPAddress)
    #  def initialize(host : Host, @base_path, @socket_type = Socket::Type::STREAM, logger = Logger.new STDERR)
    #    super host, logger
    #  end
    # end
  end
end
