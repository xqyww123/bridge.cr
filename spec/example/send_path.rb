require 'msgpack'
require 'socket'

s = UNIXSocket.new("/tmp/socks_folder/main")
"welcome".to_msgpack s
["Ruby", "female"].to_msgpack s; s.flush
u = MessagePack::Unpacker.new s
puts u.unpack

"welcome".to_msgpack s; s.flush
["Ruby, and the channel is reusable", "female"].to_msgpack s; s.flush
puts u.unpack

# the way to call a method without arguments is just to send nil.
"dog/name".to_msgpack s; s.flush
[].to_msgpack s; s.flush
u2 = MessagePack::Unpacker.new s
puts "Name of the dog is #{u2.unpack["ret"]}"

