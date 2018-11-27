module Mapping(From, To)
  include Iterable({From, To})

  abstract def [](from : From) : To
  abstract def []?(from : From) : To?
end
