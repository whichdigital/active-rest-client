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
    Rails.logger.should_receive(:info)
    Rails.logger.should_receive(:warn)
    Rails.logger.should_receive(:error)
    ActiveRestClient::Logger.debug("Hello world")
    ActiveRestClient::Logger.info("Hello world")
    ActiveRestClient::Logger.warn("Hello world")
    ActiveRestClient::Logger.error("Hello world")
    Object.send(:remove_const, :Rails)
  end

  it "should write to a logfile if one has been specified" do
    ActiveRestClient::Logger.logfile = "/dev/null"
    file = double('file')
    File.should_receive(:open).with("/dev/null", "a").and_yield(file)
    file.should_receive(:<<).with("Hello world")
    ActiveRestClient::Logger.debug("Hello world")

    file = double('file')
    File.should_receive(:open).with("/dev/null", "a").and_yield(file)
    file.should_receive(:<<).with("Hello info")
    ActiveRestClient::Logger.info("Hello info")

    file = double('file')
    File.should_receive(:open).with("/dev/null", "a").and_yield(file)
    file.should_receive(:<<).with("Hello error")
    ActiveRestClient::Logger.error("Hello error")

    file = double('file')
    File.should_receive(:open).with("/dev/null", "a").and_yield(file)
    file.should_receive(:<<).with("Hello warn")
    ActiveRestClient::Logger.warn("Hello warn")
  end

  it "should append to its own messages list if neither Rails nor a logfile has been specified" do
    File.should_not_receive(:open)
    ActiveRestClient::Logger.debug("Hello world")
    ActiveRestClient::Logger.info("Hello info")
    ActiveRestClient::Logger.warn("Hello warn")
    ActiveRestClient::Logger.error("Hello error")
    expect(ActiveRestClient::Logger.messages.size).to eq(4)
    expect(ActiveRestClient::Logger.messages[0]).to eq("Hello world")
    expect(ActiveRestClient::Logger.messages[1]).to eq("Hello info")
    expect(ActiveRestClient::Logger.messages[2]).to eq("Hello warn")
    expect(ActiveRestClient::Logger.messages[3]).to eq("Hello error")
  end

end
