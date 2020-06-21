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
end
