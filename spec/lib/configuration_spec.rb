require 'spec_helper'

describe ActiveRestClient::Configuration do
  before :each do
    Object.send(:remove_const, :ConfigurationExample) if defined?(ConfigurationExample)
    ActiveRestClient::Base._reset_configuration!

    class ConfigurationExample
      include ActiveRestClient::Configuration
      base_url "http://www.example.com"
    end
  end

  it "should default to non-whiny missing methods" do
    class UnusuedConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(UnusuedConfigurationExample1.whiny_missing).to be_false
  end

  it "should allow whiny missing methods to be enabled" do
    ConfigurationExample.whiny_missing true
    expect(ConfigurationExample.whiny_missing).to be_true
  end

  it "should remember the set base_url" do
    expect(ConfigurationExample.base_url).to eq("http://www.example.com")
  end

end
