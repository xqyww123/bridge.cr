module Bridge
  abstract class Multiplexer(HostBinding)
    def origins
      HostBinding.interfaces.keys
    end

    abstract def multiplex(origin_interface : String) : String
    abstract def multiplexed_size : Int32

    abstract def multiplex(origin_interface : String, arg : InterfaceArgument(HostBinding)) : String
    # Returns the origin interface of the `connection` on the multiplexed interface.
    abstract def select(multiplexed_interface : String, arg : InterfaceArgument(HostBinding)) : String

    # if the multiplexer compact all into one interface, the name should be `UNIQUE_INTERFACE`
    UNIQUE_INTERFACE = "main"

    abstract class Unique(HostBinding) < Multiplexer(HostBinding)
      def multiplex(origin_interface : String) : String
        UNIQUE_INTERFACE
      end

      def multiplexed_size
        1
      end
    end

    class NoMultiplex(HostBinding) < Multiplexer::Unique(HostBinding)
      def multiplex(origin_interface : String) : String
        origin_interface
      end

      def multiplex(origin_interface : String, arg : InterfaceArgument(HostBinding)) : String
        origin_interface
      end

      def select(multiplexed_interface : String, arg : InterfaceArgument(HostBinding)) : String
        multiplexed_interface
      end

      def multiplexed_size
        origins.size
      end
    end
  end

  # # A hash map from original interface path to the multiplexed.
  # struct MultiplexedSet
  #  @data : Hash(String, String)

  #  # data : the map from the origin to the multiplexed
  #  def initialize(@data)
  #  end

  #  # data : the map from the origin to the multiplexed
  #  def initialize(data : Iterator({Iterable(String), String}))
  #    @data = {} of String => String
  #    data.each { |origin_interfaces, multiplexed_interface|
  #      origin_interfaces.each { |int| @data[int] = multiplexed_interface }
  #    }
  #  end

  #  delegate size, :[], to: @data

  #  # Returns all the origin path mapped to `multiplexed_interface`.
  #  # Complexity : O(N), where N is size of the `MultiplexedSet`
  #  def origin_of(multiplexed_interface : String) : Iterable(String)
  #    SetOf.new self, multiplexed_interface
  #  end

  #  # :nodoc:
  #  struct SetOf
  #    include Iterable(String)
  #    getter all_set : MultiplexedSet
  #    getter multiplexed_interface : String

  #    def initialize(@all_set, @multiplexed_interface)
  #    end

  #    def includes?(origin_interface : String)
  #      @all_set[origin_interface] == @multiplexed_interface
  #    end

  #    def each
  #      Iterator.new self
  #    end

  #    struct Iterator
  #      include ::Iterator(String)
  #      @set_of : SetOf

  #      def initialize(@set_of)
  #        @iter = @set_of.all_set.each
  #      end

  #      def next : Stop | String
  #        until (ret = @iter.next).is_a?(Stop) || ret.last != @set_of.multiplexed_interface
  #        end
  #        ret
  #      end

  #      delegate rewind, to: @iter
  #    end
  #  end
  # end
end
