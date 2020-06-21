class Lake(T)
  DEFAULT_CAPACITY = 24

  def initialize(capacity : Int32 = DEFAULT_CAPACITY, @factory : Proc(T) = ->{ T.new })
    @mutex = Mutex.new
    @lake = Array(Tuple(Channel(T ->), T)).new(capacity)
    @cursor = 0
    capacity.times do
      chan = Channel(T ->).new
      obj = @factory.call
      @lake << {chan, obj}
      spawn { loop { chan.receive.call(obj) } }
    end
  end

  delegate size, to: @lake
  
  def [](index)
    @lake[index][1]
  end

  def first
    @lake.first[1]
  end

  def last
    @lake.last[1]
  end

  def dip(&block : T ->)
    spawn { dip_sync(&block) }
  end

  def dip_sync(&block : T ->)
    @mutex.synchronize { @lake[(@cursor += 1) % @lake.size].first.send(block) }
  end
end
