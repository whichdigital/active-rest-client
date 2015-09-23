require 'spec_helper'

describe ActiveRestClient::Configuration do
  before :each do
    Object.send(:remove_const, :ConfigurationExample) if defined?(ConfigurationExample)
    ActiveRestClient::Base._reset_configuration!

    class ConfigurationExample
      include ActiveRestClient::Configuration
      base_url "http://www.example.com"
      username "john"
      password "smith"
      request_body_type :json
    end

    class ConfigurationExampleBare
      include ActiveRestClient::Configuration
    end
  end

  it "should default to non-whiny missing methods" do
    class UnusuedConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(UnusuedConfigurationExample1.whiny_missing).to be_falsey
  end

  it "should allow whiny missing methods to be enabled" do
    ConfigurationExample.whiny_missing true
    expect(ConfigurationExample.whiny_missing).to be_truthy
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
    ActiveRestClient::Base.base_url = ""
  end

  it "should remember the set base_url on the base class if a more specific one hasn't been set" do
    ActiveRestClient::Base.base_url = "http://general.example.com"
    expect(ConfigurationExampleBare.base_url).to eq("http://general.example.com")
    ActiveRestClient::Base.base_url = ""
  end

  it "should remove a trailing slash from a specific class configured base_url" do
    class ConfigurationExample2
      include ActiveRestClient::Configuration
      base_url "http://specific.example.com/"
    end
    expect(ConfigurationExample2.base_url).to eq("http://specific.example.com")
  end

  it "should remember the set username" do
    expect(ConfigurationExample.username).to eq("john")
  end

  it "should remember the set username on a class, overriding a general one" do
    ActiveRestClient::Base.username = "bill"
    expect(ConfigurationExample.username).to eq("john")
    ActiveRestClient::Base.username = nil
  end

  it "should escape the username" do
    ActiveRestClient::Base.username = "bill@example.com"
    expect(ActiveRestClient::Base.username).to eq("bill%40example.com")
    ActiveRestClient::Base.username = nil
  end

  it "should not doubly escape the username" do
    ActiveRestClient::Base.username = "bill%40example.com"
    expect(ActiveRestClient::Base.username).to_not eq("bill%2540example.com")
    ActiveRestClient::Base.username = nil
  end

  it "should remember the set password" do
    expect(ConfigurationExample.password).to eq("smith")
  end

  it "should remember the set password on a class, overriding a general one" do
    ActiveRestClient::Base.password = "bloggs"
    expect(ConfigurationExample.password).to eq("smith")
    ActiveRestClient::Base.password = nil
  end

  it "should escape the password" do
    ActiveRestClient::Base.password = "something@else"
    expect(ActiveRestClient::Base.password).to eq("something%40else")
    ActiveRestClient::Base.password = nil
  end

  it "should not doubly escape the password" do
    ActiveRestClient::Base.password = "something%40else"
    expect(ActiveRestClient::Base.password).to_not eq("something%2540else")
    ActiveRestClient::Base.password = nil
  end

  it "should default to a form_encoded request_body_type" do
    expect(ActiveRestClient::Base.request_body_type).to eq(:form_encoded)
  end

  it "should remember the request_body_type" do
    expect(ConfigurationExample.request_body_type).to eq(:json)
  end

  it "should remember the set base_url on a class, overriding a general one" do
    ActiveRestClient::Base.request_body_type = :unknown
    expect(ActiveRestClient::Base.request_body_type).to eq(:unknown)
    expect(ConfigurationExample.request_body_type).to eq(:json)
  end

  it "should default to non-lazy loading" do
    class LazyLoadingConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(LazyLoadingConfigurationExample1.lazy_load?).to be_falsey
  end

  it "should be able to switch on lazy loading" do
    class LazyLoadingConfigurationExample2
      include ActiveRestClient::Configuration
      lazy_load!
    end
    expect(LazyLoadingConfigurationExample2.lazy_load?).to be_truthy
  end

  describe 'api auth' do
    context 'default' do
      it "should be false using_api_auth?" do
        expect(ActiveRestClient::Base.using_api_auth?).to be_falsey
      end
    end

    context 'setting api auth credentials' do
      before(:each) do
        ConfigurationExample.api_auth_credentials('id123', 'secret123')
      end

      it "should remember setting using_api_auth?" do
        expect(ConfigurationExample.using_api_auth?).to be_truthy
      end

      it "should remember setting api_auth_access_id" do
        expect(ConfigurationExample.api_auth_access_id).to eq('id123')
      end

      it "should remember setting api_auth_secret_key" do
        expect(ConfigurationExample.api_auth_secret_key).to eq('secret123')
      end

      it "should inherit api_auth_credentials when not set" do
        class ConfigurationExtension < ConfigurationExample
        end
        expect(ConfigurationExtension.api_auth_access_id).to eq('id123')
        expect(ConfigurationExtension.api_auth_secret_key).to eq('secret123')
      end

      it "should override inherited api_auth_credentials when set" do
        class ConfigurationExtension2 < ConfigurationExample
        end
        ConfigurationExtension2.api_auth_credentials('id456', 'secret456')
        expect(ConfigurationExtension2.api_auth_access_id).to eq('id456')
        expect(ConfigurationExtension2.api_auth_secret_key).to eq('secret456')
      end
    end
  end

  it "should default to non-verbose loggingg" do
    class VerboseConfigurationExample1
      include ActiveRestClient::Configuration
    end
    expect(VerboseConfigurationExample1.verbose).to be_falsey
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
    expect(VerboseConfigurationExample2.verbose).to be_truthy
    expect(VerboseConfigurationExample3.verbose).to be_truthy
  end

  it "should store a translator given" do
    expect{ ConfigurationExample.send(:translator) }.to_not raise_error
    ConfigurationExample.send(:translator, String.new)
    expect(ConfigurationExample.translator).to respond_to(:length)
  end

  it "should store a proxy given" do
    expect{ ConfigurationExample.send(:proxy) }.to_not raise_error
    ConfigurationExample.send(:proxy, String.new)
    expect(ConfigurationExample.proxy).to respond_to(:length)
  end

  describe "faraday_config" do
    let(:faraday_double){double(:faraday).as_null_object}

    it "should use default adapter if no other block set" do
      expect(faraday_double).to receive(:adapter).with(Faraday.default_adapter)
      ConfigurationExample.faraday_config.call(faraday_double)
    end

    it "should us set adapter if no other block set" do
      ConfigurationExample.adapter = :net_http

      expect(faraday_double).to receive(:adapter).with(:net_http)

      ConfigurationExample.faraday_config.call(faraday_double)
    end

    it "should use the adapter of the passed in faraday_config block" do
      ConfigurationExample.faraday_config {|faraday| faraday.adapter(:rack)}

      expect(faraday_double).to receive(:adapter).with(:rack)

      ConfigurationExample.faraday_config.call(faraday_double)
    end

  end

end
