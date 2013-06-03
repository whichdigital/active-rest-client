require 'spec_helper'

class ConnectionManagerExample
  include ActiveRestClient::ConnectionManager

  def self.base_url
    "http://www.example.com"
  end
end

describe ActiveRestClient::ConnectionManager do
  it "should have a get_connection method" do
    expect(ConnectionManagerExample).to respond_to("get_connection")
  end

  it "should return a connection for a given base url" do
    connection = ConnectionManagerExample.get_connection()
    expect(connection).to be_kind_of(ActiveRestClient::Connection)
  end

  it "should return the same connection for each base url when re-requested" do
    connection = ConnectionManagerExample.get_connection()
    expect(ConnectionManagerExample.get_connection()).to eq(connection)
  end
end
