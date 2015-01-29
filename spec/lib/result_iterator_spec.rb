require 'spec_helper'

describe ActiveRestClient::ResultIterator do
  it "should be able to have a status set during creation" do
    result = ActiveRestClient::ResultIterator.new(200)
    expect(result._status).to eq(200)
  end

  it "should be able to have a status set after creation" do
    result = ActiveRestClient::ResultIterator.new
    result._status = 200
    expect(result._status).to eq(200)
  end

  it "should remember objects given to it" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result.each do |element|
      expect(element).to eq("a")
    end
  end

  it "should implement first" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result.first).to eq("a")
  end

  it "should implement any?" do
    result = ActiveRestClient::ResultIterator.new
    expect(result.any?).to be_falsey
    result << "a"
    expect(result.any?).to be_truthy
  end

  it "should implement items" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "ab"
    expect(result.items).to eq(["a","ab"])
  end

  it "should implement last" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result.last).to eq("z")
  end

  it "should implement size" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result.size).to eq(2)
  end

  it "should implement index" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result.index("z")).to eq(1)
  end

  it "should implement empty?" do
    result = ActiveRestClient::ResultIterator.new
    expect(result.empty?).to be_truthy
    result << "a"
    result << "z"
    expect(result.empty?).to be_falsey
  end

  it "should implement direct index access" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result[0]).to eq("a")
    expect(result[1]).to eq("z")
  end

  it "should implement shuffle" do
    result = ActiveRestClient::ResultIterator.new
    100.times do |n|
      result << n
    end
    expect(result.shuffle.first == result.shuffle.first && result.shuffle.first == result.shuffle.first).to_not be_truthy
  end

  it "can parallelise calls to each item" do
    result = ActiveRestClient::ResultIterator.new
    result << 3
    result << 2
    result << 1
    delay = 0.05
    start_time = Time.now
    response = result.parallelise do |item|
      sleep(delay * item)
      item*2
    end
    end_time = Time.now
    expect(end_time-start_time).to be < (6*delay)
    expect(response).to eq([6,4,2])
  end
end
