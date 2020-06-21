class Pool(T)
  DEFAULT_CAPACITY = 24

  def initialize(capacity : Int32 = DEFAULT_CAPACITY, @factory : Proc(T) = ->{ T.new })
    @mutex = Mutex.new
    @pool = Array(Tuple(Channel(T ->), T)).new(capacity)
    @cursor = 0
    capacity.times do
      chan = Channel(T ->).new
      obj = @factory.call
      @pool << {chan, obj}
      spawn { loop { chan.receive.call(obj) } }
    end
  end

  delegate size, to: @pool
  
  def [](index)
    @pool[index][1]
  end

  def first
    @pool.first[1]
  end

  def last
    @pool.last[1]
  end

  def dip(&block : T ->)
    spawn { dip_sync(&block) }
  end

  def dip_sync(&block : T ->)
    @mutex.synchronize { @pool[(@cursor += 1) % @pool.size].first.send(block) }
  end
end
