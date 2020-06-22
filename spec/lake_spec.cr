require "./spec_helper"
require "redis"

describe Lake do
  it "fills correctly with default constructor" do
    lake = Lake(Array(String)).new
    lake.size.should eq Lake::DEFAULT_CAPACITY
  end

  it "fills correctly when overriding capacity" do
    lake = Lake(Set(Int32)).new(10)
    lake.size.should eq 10
  end

  it "fills correctly when specifying a custom factory" do
    lake = Lake(Int32).new(11, ->{ 7 })
    lake.size.should eq 11
  end

  describe "#dip" do
    it "works with basic objects on a single fiber" do
      lake = Lake(Hash(Symbol, Int32)).new
      Lake::DEFAULT_CAPACITY.times { lake.dip { |hash| hash[:test] = 3 } }
      Lake::DEFAULT_CAPACITY.times { lake.dip { |hash| hash[:test].should eq 3 } }
    end
  
    it "works with basic objects asynchronously" do
      lake = Lake(Hash(Symbol, Int32)).new(1000)
      chan = Channel(Nil).new
      1000.times do
        spawn do
          lake.dip do |hash|
            hash[:test] = 3
            chan.send(nil)
          end
        end
      end
      1000.times { chan.receive }
      1001.times { lake.dip { |hash| hash[:test].should eq 3 } }
    end

    it "handles asynchronous contention" do
      lake = Lake(Array(Int32)).new(1)
      chan = Channel(Nil).new
      100.times do |i|
        spawn do
          lake.dip do |arr|
            arr << i
            chan.send(nil)
          end
        end
      end
      100.times { chan.receive }
      lake.first.sum.should eq 4950
    end
  end

  describe "using redis" do
    it "fills correctly" do
      lake = Lake(Redis).new
      lake.size.should eq Lake::DEFAULT_CAPACITY
    end

    it "allows contentious dipping on the same key" do
      lake = Lake(Redis).new(8)
      chan = Channel(Nil).new
      100.times do |i|
        spawn do
          lake.dip do |redis|
            redis.incrby("lake-test-key", i)
            chan.send(nil)
          end
        end
      end
      100.times { chan.receive }
      lake.dip_sync { |redis| redis.get("lake-test-key").not_nil!.to_i.should eq 4950 }
      lake.dip_sync { |redis| redis.del("lake-test-key") }
    end

    describe "#leak" do
      it "takes an instance out of the pool and replaces it with a new one" do
        lake = Lake(Redis).new(5)
        redis = lake.leak
        lake.size.times { |i| lake[i].should_not eq redis }
        lake.size.should eq 5
      end
    end

    it "allows use of leak for stuff like pub/sub with contention" do
      lake = Lake(Redis).new(10)
      redis = lake.leak
      chan = Channel(Nil).new
      chan2 = Channel(Nil).new
      spawn do
        redis.subscribe("lake-test-channel") do |on|
          spawn { chan.send(nil) }
          on.message do |channel, message|
            redis.unsubscribe("lake-test-channel")
            chan2.send(nil)
          end
        end
      end
      lake.dip do |red|
        red.publish("lake-test-channel", "hey")
        chan2.send(nil)
      end
      chan2.receive
    end
  end
end
