class Lake(T)
  DEFAULT_CAPACITY = 24
  DEFAULT_TTL = 1.5.seconds

  property ttl : Time::Span

  def initialize(capacity : Int32 = DEFAULT_CAPACITY, @ttl : Time::Span = DEFAULT_TTL, @factory : Proc(T) = ->{ T.new })
    @mutex = Mutex.new
    @lake = Array(Tuple(Channel(T ->), T)).new(capacity)
    @live = Set(Channel(T ->)).new
    @cursor = 0
    capacity.times do |i|
      chan = Channel(T ->).new
      obj = @factory.call
      @lake << {chan, obj}
      @live << chan
      spawn_entry_event_loop(chan, obj)
    end
  end

  private def spawn_entry_event_loop(chan : Channel(T ->), obj : T)
    spawn do
      loop do
        should_break = false
        @mutex.synchronize { should_break = !@live.includes?(chan) }
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
    raise "no pool objects available" unless @lake.size > 0
    spawn { dip_sync(&block) }
  end

  def dip_sync(&block : T ->)
    raise "no pool objects available" unless @lake.size > 0
    chan = nil
    @mutex.synchronize do
      chan = @lake[(@cursor = (@cursor + 1) % @lake.size)].first
    end
    select
    when chan.not_nil!.send(block)
    when timeout(@ttl)
      new_chan = Channel(T ->).new
      new_obj = @factory.call
      @mutex.synchronize do
        @live.delete(chan)
        @live << new_chan
        @lake[@cursor] = {new_chan, new_obj} # replacement
        spawn_entry_event_loop(new_chan, new_obj)
      end
    end
  end

  def leak : T
    obj = nil
    chan = nil
    new_chan = Channel(T ->).new
    new_obj = @factory.call
    @mutex.synchronize do
      @cursor = (@cursor + 1) % @lake.size
      chan, obj = @lake[@cursor] # channel to original
      @live << new_chan
      @lake[@cursor] = {new_chan, new_obj} # replacement
      spawn_entry_event_loop(new_chan, new_obj)
    end
    chan.not_nil!.send(->(t : T) {}) # block until old object is done
    @mutex.synchronize { @live.delete(chan.not_nil!) } # kill old event loop
    obj.not_nil! # return now unused and unassociated object
  end

  def clear : Array(T)
    arr = [] of T
    @mutex.synchronize do
      @lake.each do |tuple|
        chan, obj = tuple
        chan.send(->(t : T) {})
        arr << obj
      end
      @lake.clear
      @capacity = 0
    end
    arr
  end
end
