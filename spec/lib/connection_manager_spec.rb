require 'spec_helper'

describe ActiveRestClient::ConnectionManager do
  it "should have a get_connection method" do
    class ConnectionManagerExample1
      include ActiveRestClient::ConnectionManager
    end
    expect(ConnectionManagerExample1).to respond_to("get_connection")
  end

  it "should return a connection for a given base url" do
    class ConnectionManagerExample2
      include ActiveRestClient::ConnectionManager
      def self.base_url
        "http://www.example.com"
      end
    end
    connection = ConnectionManagerExample2.get_connection()
    expect(connection).to be_kind_of(ActiveRestClient::Connection)
  end

  it "should return the same connection for each base url when re-requested" do
    class ConnectionManagerExample3
      include ActiveRestClient::ConnectionManager
      def self.base_url
        "http://www.example.com"
      end
    end
    connection = ConnectionManagerExample3.get_connection()
    expect(ConnectionManagerExample3.get_connection()).to eq(connection)
  end
end
