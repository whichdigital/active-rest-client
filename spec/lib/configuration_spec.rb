require 'spec_helper'

class ConfigurationExample
  include ActiveRestClient::Configuration

  base_url "http://www.example.com"
end

describe ActiveRestClient::Configuration do
  it "should default to non-whiny missing methods" do
    expect(ConfigurationExample.whiny_missing).to be_false
  end

  it "should remember the set base_url" do
    expect(ConfigurationExample.base_url).to eq("http://www.example.com")
  end

end
