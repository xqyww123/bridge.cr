require "spec"
require "../src/bridge"
require "msgpack"
require "tempfile.cr"
require "./example_host.cr"

include Bridge

class Tempfile
  def self.tempdir(extension) : String
    10.times do
      path = self.tempname extension
      begin
        Dir.mkdir_p path
      rescue err : Errno
        sleep 1
        next
      end
      return p path
    end
    raise "Fail to create tmp directory, try time out."
  end
end
