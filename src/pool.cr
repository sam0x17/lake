class Pool(T)
  DEFAULT_CAPACITY = 24

  def initialize(capacity = DEFAULT_CAPACITY, @factory = ->{ T.new })
    @mutex = Mutex.new
    @pool = Array(Tuple(Channel(T ->), T)).new(capacity)
    @cursor = 0
    @pool.size.times do |i|
      chan = Channel(T ->).new
      obj = @factory.call
      @pool[i] = {chan, obj}
      spawn do
        loop do
          block = chan.receive
          block.call(obj)
        end
      end
    end
  end

  def dip(&block : T ->)
    spawn { dip_sync(block) }
  end

  def dip_sync(&block : T ->)
    mutex.synchronize { @pool[(@cursor += 1) % @pool.size].first.send(block) }
  end
end
