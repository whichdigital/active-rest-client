require 'spec_helper'

describe ActiveRestClient::Recording do
  it "can confirm if a recording callback is set" do
    class MyObject1
      include ActiveRestClient::Recording
    end
    expect(MyObject1.record_response?).to be_falsey
    MyObject1.record_response do
      puts "Hello world"
    end
    expect(MyObject1.record_response?).to be_truthy
  end

  it "remembers a block given to it to later be called back" do
    class MyObject2
      include ActiveRestClient::Recording
    end
    MyObject2.record_response do
      puts "Hello world"
    end
    expect(MyObject2.instance_variable_get(:@record_response)).to_not be_nil
  end

  it "calls back to the block if record_response is given a url and response" do
    class MyObject3
      include ActiveRestClient::Recording
    end
    MyObject3.record_response do |url, response|
      raise Exception.new("#{url}|#{response}")
    end
    expect{MyObject3.record_response("http://www.example.com/", "Hello world")}.to raise_error(Exception, 'http://www.example.com/|Hello world')
  end
end
