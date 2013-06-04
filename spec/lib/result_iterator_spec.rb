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
end
