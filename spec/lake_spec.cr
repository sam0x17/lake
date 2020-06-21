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
  end
end
