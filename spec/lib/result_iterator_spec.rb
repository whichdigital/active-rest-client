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

  it "should implement first/any?" do
    result = ActiveRestClient::ResultIterator.new
    result << "a"
    result << "z"
    expect(result.first).to eq("a")
    expect(result.any?).to be_true
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
    expect(result.empty?).to be_true
    result << "a"
    result << "z"
    expect(result.empty?).to be_false
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
    expect(result.shuffle.first == result.shuffle.first && result.shuffle.first == result.shuffle.first).to_not be_true
  end
end
