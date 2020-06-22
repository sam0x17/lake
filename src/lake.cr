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
    chan = nil
    @mutex.synchronize do
      chan = @lake[(@cursor = (@cursor + 1) % @lake.size)].first
    end
    chan.not_nil!.send(block)
  end

  def leak : T
    chan = nil
    obj = nil
    @mutex.synchronize do 
      @cursor = (@cursor + 1) % @lake.size
      chan, obj = @lake[@cursor] # channel to original
      @lake[@cursor] = {Channel(T ->).new, @factory.call} # replacement
    end
    chan.not_nil!.send(->(o : T) {})
    obj.not_nil!
  end
end
