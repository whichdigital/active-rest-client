require 'spec_helper'

class ConnectionExample
  include ActiveRestClient::ConnectionManager
end

describe ActiveRestClient::ConnectionManager do
  it "should have a get_connection method" do
    expect(ConnectionExample).to respond_to("get_connection")
  end

  it "should return a connection for a given base url" do
    connection = ConnectionExample.get_connection("http://www.example.com")
    expect(connection).to be_kind_of(ActiveRestClient::Connection)
  end

  it "should return the same connection for each base url when re-requested" do
    connection = ConnectionExample.get_connection("http://www.example.com")
    expect(ConnectionExample.get_connection("http://www.example.com")).to eq(connection)
  end


end
