require 'spec_helper'

describe ActiveRestClient::Caching do
  before :each do
    ActiveRestClient::Base._reset_caching!
  end

  context "Configuration of caching" do
    it "should not have caching enabled by default" do
      class CachingExample1
        include ActiveRestClient::Caching
      end
      expect(CachingExample1.perform_caching).to be_false
    end

    it "should be able to have caching enabled without affecting ActiveRestClient::Base" do
      class CachingExample2
        include ActiveRestClient::Caching
      end
      CachingExample2.perform_caching true
      expect(CachingExample2.perform_caching).to be_true
      expect(ActiveRestClient::Base.perform_caching).to be_false
    end

    it "should be possible to enable caching for all objects" do
      class CachingExample3 < ActiveRestClient::Base ; end
      ActiveRestClient::Base._reset_caching!

      expect(ActiveRestClient::Base.perform_caching).to be_false

      ActiveRestClient::Base.perform_caching = true
      expect(ActiveRestClient::Base.perform_caching).to be_true
      expect(EmptyExample.perform_caching).to be_true

      ActiveRestClient::Base._reset_caching!
    end

    it "should use a custom cache store if a valid one is set" do
      class CachingExampleCacheStore1
        def read(key) ; end
        def write(key, value, options={}) ; end
        def fetch(key, &block) ; end
      end
      cache_store = CachingExampleCacheStore1.new
      ActiveRestClient::Base.cache_store = cache_store
      expect(ActiveRestClient::Base.cache_store).to eq(cache_store)
    end

    it "should use a custom cache store if a valid one is set" do
      class CachingExampleCacheStore2
        def write(key, value, options={}) ; end
        def fetch(key, &block) ; end
      end
      class CachingExampleCacheStore3
        def read(key) ; end
        def fetch(key, &block) ; end
      end
      class CachingExampleCacheStore4
        def read(key) ; end
        def write(key, value, options={}) ; end
      end

      expect{ ActiveRestClient::Base.cache_store = CachingExampleCacheStore2.new }.to raise_error
      expect{ ActiveRestClient::Base.cache_store = CachingExampleCacheStore3.new }.to raise_error
      expect{ ActiveRestClient::Base.cache_store = CachingExampleCacheStore4.new }.to raise_error
    end
  end

  context "Reading/writing to the cache" do
    before :each do
      Object.send(:remove_const, :CachingExampleCacheStore5) if defined?(CachingExampleCacheStore5)
      class CachingExampleCacheStore5
        def read(key) ; end
        def write(key, value, options={}) ; end
        def fetch(key, &block) ; end
      end

      class Rails
        def self.cache
          CachingExampleCacheStore5.new
        end
      end

      class Person < ActiveRestClient::Base
        perform_caching true
        base_url "http://www.example.com"
        get :all, "/"
      end

      @etag = "6527914a91e0c5769f6de281f25bd891"
      @cached_object = Person.new(first_name:"Johnny")
    end

    it "should read from the cache store, to check for an etag" do
      cached_response = ActiveRestClient::CachedResponse.new(
        status:200,
        result:@cached_object,
        etag:@etag)
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(cached_response)
      ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {"If-None-Match" => @etag}).and_return(OpenStruct.new(status:304, headers:{}))
      ret = Person.all
      expect(ret.first_name).to eq("Johnny")
    end

    it "should read from the cache store, and not call the server if there's a hard expiry" do
      cached_response = ActiveRestClient::CachedResponse.new(
        status:200,
        result:@cached_object,
        expires:Time.now + 30)
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(cached_response)
      ActiveRestClient::Connection.any_instance.should_not_receive(:get)
      ret = Person.all
      expect(ret.first_name).to eq("Johnny")
    end

    it "should read from the cache store and restore to the same object" do
      cached_response = ActiveRestClient::CachedResponse.new(
        status:200,
        result:@cached_object,
        expires:Time.now + 30)
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(cached_response)
      ActiveRestClient::Connection.any_instance.should_not_receive(:get)
      p = Person.new(first_name:"Billy")
      ret = p.all({})
      expect(ret.first_name).to eq("Johnny")
    end

    it "should restore a result iterator from the cache store, if there's a hard expiry" do
      class CachingExample3 < ActiveRestClient::Base ; end
      object = ActiveRestClient::ResultIterator.new(200)
      object << CachingExample3.new(first_name:"Johnny")
      object << CachingExample3.new(first_name:"Billy")
      etag = "6527914a91e0c5769f6de281f25bd891"
      cached_response = ActiveRestClient::CachedResponse.new(
        status:200,
        result:object,
        etag:@etag,
        expires:Time.now + 30)
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(cached_response)
      ActiveRestClient::Connection.any_instance.should_not_receive(:get)
      ret = Person.all
      expect(ret.first.first_name).to eq("Johnny")
      expect(ret._status).to eq(200)
    end

    it "should not write the response to the cache unless if has caching headers" do
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(nil)
      CachingExampleCacheStore5.any_instance.should_not_receive(:write)
      ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {}).and_return(OpenStruct.new(status:200, body:"{\"result\":true}", headers:{}))
      ret = Person.all
    end

    it "should write the response to the cache if there's an etag" do
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(nil)
      CachingExampleCacheStore5.any_instance.should_receive(:write).once.with("Person:/", an_instance_of(ActiveRestClient::CachedResponse), {})
      ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {}).and_return(OpenStruct.new(status:200, body:"{\"result\":true}", headers:{etag:"1234567890"}))
      ret = Person.all
    end

    it "should write the response to the cache if there's a hard expiry" do
      CachingExampleCacheStore5.any_instance.should_receive(:read).once.with("Person:/").and_return(nil)
      CachingExampleCacheStore5.any_instance.should_receive(:write).once.with("Person:/", an_instance_of(ActiveRestClient::CachedResponse), an_instance_of(Hash))
      ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {}).and_return(OpenStruct.new(status:200, body:"{\"result\":true}", headers:{expires:(Time.now + 30).rfc822}))
      ret = Person.all
    end

  end

end
