require "./spec_helper"

describe Pool do
  it "fills correctly with default constructor" do
    pool = Pool(Array(String)).new
    pool.size.should eq Pool::DEFAULT_CAPACITY
  end

  it "fills correctly when overriding capacity" do
    pool = Pool(Set(Int32)).new(10)
    pool.size.should eq 10
  end

  it "fills correctly when specifying a custom factory" do
    pool = Pool(Int32).new(11, ->{ 7 })
    pool.size.should eq 11
  end

  describe "#dip" do
    it "works with basic objects on a single fiber" do
      pool = Pool(Hash(Symbol, Int32)).new
      Pool::DEFAULT_CAPACITY.times { pool.dip { |hash| hash[:test] = 3 } }
      Pool::DEFAULT_CAPACITY.times { pool.dip { |hash| hash[:test].should eq 3 } }
    end
  
    it "works with basic objects asynchronously" do
      pool = Pool(Hash(Symbol, Int32)).new(1000)
      chan = Channel(Nil).new
      1000.times do
        spawn do
          pool.dip do |hash|
            hash[:test] = 3
            chan.send(nil)
          end
        end
      end
      1000.times { chan.receive }
      1001.times { pool.dip { |hash| hash[:test].should eq 3 } }
    end

    it "handles asynchronous contention" do
      pool = Pool(Array(Int32)).new(1)
      chan = Channel(Nil).new
      100.times do |i|
        spawn do
          pool.dip do |arr|
            arr << i
            chan.send(nil)
          end
        end
      end
      100.times { chan.receive }
      pool.first.sum.should eq 4950
    end
  end
end
