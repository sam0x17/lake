class Lake(T)
  DEFAULT_CAPACITY = 24

  def initialize(capacity : Int32 = DEFAULT_CAPACITY, @factory : Proc(T) = ->{ T.new })
    @mutex = Mutex.new
    @lake = Array(Tuple(Channel(T ->), T, Bool)).new(capacity)
    @cursor = 0
    capacity.times do |i|
      chan = Channel(T ->).new
      obj = @factory.call
      @lake << {chan, obj, true}
      spawn_entry_event_loop(chan, obj, i)
    end
  end

  private def spawn_entry_event_loop(chan : Channel(T ->), obj : T, i : Int32)
    spawn do
      loop do
        should_break = false
        @mutex.synchronize { should_break = !@lake[i][2] }
        break if should_break
        chan.receive.call(obj)
      end
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
    obj = nil
    @mutex.synchronize do 
      @cursor = (@cursor + 1) % @lake.size
      chan, obj = @lake[@cursor] # channel to original
      new_chan = Channel(T ->).new
      new_obj = @factory.call
      @lake[@cursor] = {new_chan, new_obj, true} # replacement
      spawn_entry_event_loop(new_chan, new_obj, @cursor)
    end
    obj.not_nil!
  end
end
