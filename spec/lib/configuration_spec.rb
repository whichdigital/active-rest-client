require 'spec_helper'

describe ActiveRestClient::Configuration do
  before :each do
    Object.send(:remove_const, :ConfigurationExample) if defined?(ConfigurationExample)
    ActiveRestClient::Base._reset_configuration!

    class ConfigurationExample
      include ActiveRestClient::Configuration
      base_url "http://www.example.com"
    end

    class ConfigurationExampleBare
      include ActiveRestClient::Configuration
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

  it "should remember the set base_url on a class, overriding a general one" do
    ActiveRestClient::Base.base_url = "http://general.example.com"
    expect(ConfigurationExample.base_url).to eq("http://www.example.com")
  end

  it "should remove a trailing slash from a globally configured base_url" do
    ActiveRestClient::Base.base_url = "http://general.example.com/"
    expect(ConfigurationExample.base_url).to eq("http://www.example.com")
  end

  it "should remember the set base_url on the base class if a more specific one hasn't been set" do
    ActiveRestClient::Base.base_url = "http://general.example.com"
    expect(ConfigurationExampleBare.base_url).to eq("http://general.example.com")
  end

  it "should remove a trailing slash from a specific class configured base_url" do
    class ConfigurationExample2
      include ActiveRestClient::Configuration
      base_url "http://specific.example.com/"
    end
    expect(ConfigurationExample2.base_url).to eq("http://specific.example.com")
  end

  it "should default to non-lazy loading" do
    class LazyLoadingConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(LazyLoadingConfigurationExample1.lazy_load?).to be_false
  end

  it "should be able to switch on lazy loading" do
    class LazyLoadingConfigurationExample2
      include ActiveRestClient::Configuration
      lazy_load!
    end
    expect(LazyLoadingConfigurationExample2.lazy_load?).to be_true
  end

  it "should default to non-verbose loggingg" do
    class VerboseConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(VerboseConfigurationExample1.verbose).to be_false
  end

  it "should be able to switch on verbose logging" do
    class VerboseConfigurationExample2
      include ActiveRestClient::Configuration
      verbose!
    end
    class VerboseConfigurationExample3
      include ActiveRestClient::Configuration
      verbose true
    end
    expect(VerboseConfigurationExample2.verbose).to be_true
    expect(VerboseConfigurationExample3.verbose).to be_true
  end

  it "should store a translator given" do
    expect{ ConfigurationExample.send(:translator) }.to_not raise_error
    ConfigurationExample.send(:translator, String)
    expect{ ConfigurationExample.translator.respond_to?(:length) }.to be_true
  end

  it "should store a proxy given" do
    expect{ ConfigurationExample.send(:proxy) }.to_not raise_error
    ConfigurationExample.send(:proxy, String)
    expect{ ConfigurationExample.proxy.respond_to?(:length) }.to be_true
  end

  describe "faraday_config" do
    let(:faraday_double){double(:faraday).as_null_object}

    it "should use default adapter if no other block set" do
      faraday_double.should_receive(:adapter).with(:patron)
      ConfigurationExample.faraday_config.call(faraday_double)
    end

    it "should us set adapter if no other block set" do
      ConfigurationExample.adapter = :net_http

      faraday_double.should_receive(:adapter).with(:net_http)

      ConfigurationExample.faraday_config.call(faraday_double)
    end

    it "should use the adapter of the passed in faraday_config block" do
      ConfigurationExample.faraday_config {|faraday| faraday.adapter(:rack)}

      faraday_double.should_receive(:adapter).with(:rack)

      ConfigurationExample.faraday_config.call(faraday_double)
    end

  end

end
