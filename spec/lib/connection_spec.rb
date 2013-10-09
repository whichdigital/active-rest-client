require 'spec_helper'

describe ActiveRestClient::Connection do
  before(:each) do
    @connection = ActiveRestClient::Connection.new("http://www.example.com")
  end

  it "should contain a patron session" do
    expect(@connection.session).to be_a_kind_of(Patron::Session)
  end

  it "should set the Base URL for Patron to be the one passed in" do
    expect(@connection.session.base_url).to eq("http://www.example.com")
  end

  it "should set a user agent for the Patron session" do
    expect(@connection.headers["User-Agent"]).to match(/^ActiveRestClient\/[0-9.]+$/)
  end

  it "should try to Keep-Alive Patron session connections" do
    expect(@connection.headers["Connection"]).to match(/Keep-Alive/)
  end

  it "should pass a GET request through to Patron" do
    @connection.session = double(Patron::Session)
    @connection.session.stub(:get).with("/foo", {}).and_return(OpenStruct.new(body:"{result:true}"))
    result = @connection.get("/foo")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a PUT request through to Patron" do
    @connection.session = double(Patron::Session)
    @connection.session.stub(:put).with("/foo", "body", {}).and_return(OpenStruct.new(body:"{result:true}"))
    result = @connection.put("/foo", "body")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a POST request through to Patron" do
    @connection.session = double(Patron::Session)
    @connection.session.stub(:post).with("/foo", "body", {}).and_return(OpenStruct.new(body:"{result:true}"))
    result = @connection.post("/foo", "body")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a DELETE request through to Patron" do
    @connection.session = double(Patron::Session)
    @connection.session.stub(:delete).with("/foo", {}).and_return(OpenStruct.new(body:"{result:true}"))
    result = @connection.delete("/foo")
    expect(result.body).to eq("{result:true}")
  end

  it "should retry once in the event of a connection failed" do
    @times_called = 0
    Patron::Session.any_instance.stub(:get).and_return do
      raise Patron::ConnectionFailed.new("Foo") if (@times_called += 1) == 1
    end
    expect { @connection.get("/foo") }.to_not raise_error
  end

  it "should not retry more than once in the event of a connection failed" do
    @times_called = 0
    Patron::Session.any_instance.stub(:get).and_return do
      raise Patron::ConnectionFailed.new("Foo")
    end
    expect { @connection.get("/foo") }.to raise_error(ActiveRestClient::ConnectionFailedException)
  end

  it "should raise an exception on timeout" do
    Patron::Session.any_instance.stub(:get).and_raise Patron::TimeoutError.new("Foo")
    expect { @connection.get("/foo") }.to raise_error(ActiveRestClient::TimeoutException)
  end

end
