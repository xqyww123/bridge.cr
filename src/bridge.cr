require "socket"
require "./bridge/*"

module Bridge
  VERSION = "0.1.0"

  alias UnixSocket = Driver::UnixSocket
end
