class Pool(T)
  DEFAULT_CAPACITY = 24

  def initialize(capacity = DEFAULT_CAPACITY)
    @pool = Array(T).new(capacity)
    @pool_commands = Array
    @mutex : Mutex
    @cursor = 0
  end

  def borrow(&block : T ->)
    @mutex.synchronize do
      return 
    end
  end
end
