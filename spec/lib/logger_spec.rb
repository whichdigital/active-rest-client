require 'spec_helper'

describe ActiveRestClient::Instrumentation do
  before :each do
    ActiveRestClient::Logger.reset!
  end

  it "should log things to the Rails logger if available" do
    class Rails
      class << self
        attr_accessor :logger
      end
    end

    Rails.logger = double("Logger")
    Rails.logger.should_receive(:debug)
    Rails.logger.should_receive(:error)
    ActiveRestClient::Logger.debug("Hello world")
    ActiveRestClient::Logger.error("Hello world")
    Object.send(:remove_const, :Rails)
  end

  it "should write to a logfile if one has been specified" do
    ActiveRestClient::Logger.logfile = "test.log"
    file = mock('file')
    File.should_receive(:open).with("test.log", "a").and_yield(file)
    file.should_receive(:<<).with("Hello world")
    ActiveRestClient::Logger.debug("Hello world")

    file = mock('file')
    File.should_receive(:open).with("test.log", "a").and_yield(file)
    file.should_receive(:<<).with("Hello error")
    ActiveRestClient::Logger.error("Hello error")
  end

  it "should append to its own messages list if neither Rails nor a logfile has been specified" do
    File.should_not_receive(:open)
    ActiveRestClient::Logger.debug("Hello world")
    ActiveRestClient::Logger.error("Hello error")
    expect(ActiveRestClient::Logger.messages.size).to eq(2)
    expect(ActiveRestClient::Logger.messages[0]).to eq("Hello world")
    expect(ActiveRestClient::Logger.messages[1]).to eq("Hello error")
  end

end
