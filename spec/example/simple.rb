require 'msgpack'
require 'socket'

s = UNIXSocket.new("/tmp/socks_folder/welcome")
["Ruby", "female"].to_msgpack s; s.flush
u = MessagePack::Unpacker.new s
puts u.unpack

["Ruby, and the channel is usable", "female"].to_msgpack s; s.flush
puts u.unpack

s2 = UNIXSocket.new("/tmp/socks_folder/dog/name")
# the way to call a method without arguments is just to send nil.
nil.to_msgpack s2; s2.flush
u2 = MessagePack::Unpacker.new s2
puts "Name of the dog is #{u2.unpack}"

