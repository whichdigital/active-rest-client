require 'spec_helper'

describe ActiveRestClient::Connection do
  before do
    @connection = ActiveRestClient::Connection.new("http://www.example.com")
  end

  it "should contain a Farday connection" do
    expect(@connection.session).to be_a_kind_of(Faraday::Connection)
  end

  it "should set the Base URL to be the one passed in" do
    expect(@connection.session.url_prefix.to_s).to eq("http://www.example.com/")
  end

  it "should set a user agent for the session" do
    expect(@connection.headers["User-Agent"]).to match(/^ActiveRestClient\/[0-9.]+$/)
  end

  it "should try to Keep-Alive session connections" do
    expect(@connection.headers["Connection"]).to match(/Keep-Alive/)
  end

  it "should pass a GET request through to Faraday" do
    stub_request(:get, "www.example.com/foo").to_return(body: "{result:true}")
    result = @connection.get("/foo")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a PUT request through to Faraday" do
    stub_request(:put, "www.example.com/foo").with(body: "body").to_return(body: "{result:true}")
    result = @connection.put("/foo", "body")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a POST request through to Faraday" do
    stub_request(:post, "www.example.com/foo").with(body: "body").to_return(body: "{result:true}")
    result = @connection.post("/foo", "body")
    expect(result.body).to eq("{result:true}")
  end

  it "should pass a DELETE request through to Faraday" do
    stub_request(:delete, "www.example.com/foo").to_return(body: "{result:true}")
    result = @connection.delete("/foo")
    expect(result.body).to eq("{result:true}")
  end

  it "should retry once in the event of a connection failed" do
    stub_request(:get, "www.example.com/foo").to_raise(Faraday::ConnectionFailed.new("Foo"))
    expect { @connection.get("/foo") }.to raise_error(ActiveRestClient::ConnectionFailedException)
  end

  it "should raise an exception on timeout" do
    stub_request(:get, "www.example.com/foo").to_timeout
    expect { @connection.get("/foo") }.to raise_error(ActiveRestClient::TimeoutException)
  end

end
