class Lake(T)
  DEFAULT_CAPACITY = 24
  @@current_id : Int64 = 0

  def initialize(capacity : Int32 = DEFAULT_CAPACITY, @factory : Proc(T) = ->{ T.new })
    @mutex = Mutex.new
    @lake = Array(Tuple(Channel(T ->), T)).new(capacity)
    @live = Hash(Channel(T ->), Bool).new
    @cursor = 0
    capacity.times do |i|
      chan = Channel(T ->).new
      obj = @factory.call
      @lake << {chan, obj}
      @live[chan] = true
      @@current_id += 1
      spawn_entry_event_loop(chan, obj)
    end
  end

  private def spawn_entry_event_loop(chan : Channel(T ->), obj : T)
    spawn do
      loop do
        should_break = false
        @mutex.synchronize { should_break = !@live[chan] }
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
    chan = nil
    @mutex.synchronize do
      @cursor = (@cursor + 1) % @lake.size
      chan, obj = @lake[@cursor] # channel to original
      new_chan = Channel(T ->).new
      new_obj = @factory.call
      @live[new_chan] = true
      @lake[@cursor] = {new_chan, new_obj} # replacement
      spawn_entry_event_loop(new_chan, new_obj)
    end
    chan.not_nil!.send(->(t : T) {}) # block until old object is done
    @mutex.synchronize { @live[chan.not_nil!] = false } # kill old event loop
    obj.not_nil! # return now unused and unassociated object
  end
end
