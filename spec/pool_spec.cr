require "./spec_helper"

describe Pool do
  it "fills correctly with default constructor" do
    pool = Pool(Array(String)).new
    pool.size.should eq Pool::DEFAULT_CAPACITY
    pool.empty?.should eq false
  end
end
