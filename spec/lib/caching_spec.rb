require 'spec_helper'

describe ActiveRestClient::Caching do
  before :each do
    Object.send(:remove_const, :CachingExample) if defined?(CachingExample)
    ActiveRestClient::Base._reset_caching!

    class CachingExample
      include ActiveRestClient::Caching
    end
  end

  it "should not have caching enabled by default" do
    class UnusuedCachingExample1
      include ActiveRestClient::Caching
    end
    expect(UnusuedCachingExample1.perform_caching).to be_false
  end

  it "should be able to have caching enabled without affecting ActiveRestClient::Base" do
    class UnusuedCachingExample2
      include ActiveRestClient::Caching
    end
    UnusuedCachingExample2.perform_caching true
    expect(UnusuedCachingExample2.perform_caching).to be_true
    expect(ActiveRestClient::Base.perform_caching).to be_false
  end

  it "should use a custom cache store if one is set" do
    CachingExample.perform_caching true
    expect(CachingExample.perform_caching).to be_true
    expect(ActiveRestClient::Base.perform_caching).to be_false
  end

end
