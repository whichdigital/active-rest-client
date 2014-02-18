require 'spec_helper'

class EmptyExample < ActiveRestClient::Base
  whiny_missing true
end

class TranslatorExample
  def self.all(object)
    ret = {}
    ret["first_name"] = object["name"]
    ret
  end
end

class AlteringClientExample < ActiveRestClient::Base
  translator TranslatorExample
  base_url "http://www.example.com"

  get :all, "/all", fake:"{\"name\":\"Billy\"}"
  get :list, "/list", fake:"{\"name\":\"Billy\", \"country\":\"United Kingdom\"}"
  get :iterate, "/iterate", fake:"{\"name\":\"Billy\", \"country\":\"United Kingdom\"}"
  get :find, "/find/:id"
end

class RecordResponseExample < ActiveRestClient::Base
  base_url "http://www.example.com"

  record_response do |url, response|
    raise Exception.new("#{url}|#{response.body}")
  end

  get :all, "/all"
end

describe ActiveRestClient::Base do
  it 'should instantiate a new descendant' do
    expect{EmptyExample.new}.to_not raise_error(Exception)
  end

  it "should not instantiate a new base class" do
    expect{ActiveRestClient::Base.new}.to raise_error(Exception)
  end

  it "should save attributes passed in constructor" do
    client = EmptyExample.new(:test => "Something")
    expect(client._attributes[:test]).to be_a(String)
  end

  it "should allow attribute reading using missing method names" do
    client = EmptyExample.new(:test => "Something")
    expect(client.test).to eq("Something")
  end

  it "should allow attribute reading using [] array notation" do
    client = EmptyExample.new(:test => "Something")
    expect(client["test"]).to eq("Something")
  end

  it "allows iteration over attributes using each" do
    client = AlteringClientExample.iterate
    expect(client).to be_respond_to(:each)
    keys = []
    values = []
    client.each do |key, value|
      keys << key ; values << value
    end
    expect(keys).to eq(%w{name country}.map(&:to_sym))
    expect(values).to eq(["Billy", "United Kingdom"])
  end

  it "should automatically parse ISO 8601 format dates" do
    t = Time.now
    client = EmptyExample.new(:test => t.iso8601)
    expect(client["test"]).to be_an_instance_of(DateTime)
    expect(client["test"].to_s).to eq(t.to_datetime.to_s)
  end

  it "should store attributes set using missing method names and mark them as dirty" do
    client = EmptyExample.new()
    client.test = "Something"
    expect(client.test.to_s).to eq("Something")
    expect(client).to be_dirty
  end

  it "should store attribute set using []= array notation and mark them as dirty" do
    client = EmptyExample.new()
    client["test"] = "Something"
    expect(client["test"].to_s).to eq("Something")
    expect(client).to be_dirty
  end

  it "should overwrite attributes already set and mark them as dirty" do
    client = EmptyExample.new(:hello => "World")
    client._clean!
    expect(client).to_not be_dirty

    client.hello = "Everybody"
    expect(client).to be_dirty
  end

  it 'should respond_to? attributes defined in the response' do
    client = EmptyExample.new(:hello => "World")
    client.respond_to?(:hello).should be_true
    client.respond_to?(:world).should be_false
  end

  it "should save the base URL for the API server" do
    class BaseExample < ActiveRestClient::Base
      base_url "https://www.example.com/api/v1"
    end
    expect(BaseExample.base_url).to eq("https://www.example.com/api/v1")
  end

  it "should allow changing the base_url while running" do
    class OutsideBaseExample < ActiveRestClient::Base ; end

    ActiveRestClient::Base.base_url = "https://www.example.com/api/v1"
    expect(OutsideBaseExample.base_url).to eq("https://www.example.com/api/v1")

    ActiveRestClient::Base.base_url = "https://www.example.com/api/v2"
    expect(OutsideBaseExample.base_url).to eq("https://www.example.com/api/v2")
  end

  it "should include the Mapping module" do
    expect(EmptyExample).to respond_to(:_calls)
    expect(EmptyExample).to_not respond_to(:_non_existant)
  end

  it "should be able to easily clean all attributes" do
    client = EmptyExample.new(hello:"World", goodbye:"Everyone")
    expect(client).to be_dirty
    client._clean!
    expect(client).to_not be_dirty
  end

  it "should not overly pollute the instance method namespace to reduce chances of clashing (<10 instance methods)" do
    instance_methods = EmptyExample.instance_methods - Object.methods
    instance_methods = instance_methods - instance_methods.grep(/^_/)
    expect(instance_methods.size).to be < 10
  end

  it "should raise an exception for missing attributes if whiny_missing is enabled" do
    expect{EmptyExample.new.first_name}.to raise_error(ActiveRestClient::NoAttributeException)
  end

  it "should be able to lazy instantiate an object from a prefixed lazy_ method call" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with('/find/1', anything).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
    example = AlteringClientExample.lazy_find(1)
    expect(example).to be_an_instance_of(ActiveRestClient::LazyLoader)
    expect(example.first_name).to eq("Billy")
  end

  it "should be able to lazy instantiate an object from a prefixed lazy_ method call from an instance" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with('/find/1', anything).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
    example = AlteringClientExample.new.lazy_find(1)
    expect(example).to be_an_instance_of(ActiveRestClient::LazyLoader)
    expect(example.first_name).to eq("Billy")
  end

  context "accepts a Translator to reformat JSON" do
    it "should log a deprecation warning when using a translator" do
      ActiveRestClient::Logger.should_receive(:warn) do |message|
        expect(message).to start_with("DEPRECATION")
      end
      Proc.new do
        class DummyExample < ActiveRestClient::Base
          translator TranslatorExample
        end
      end.call
    end

    it "should call Translator#method when calling the mapped method if it responds to it" do
      TranslatorExample.should_receive(:all).with(an_instance_of(Hash)).and_return({})
      AlteringClientExample.all
    end

    it "should not raise errors when calling Translator#method if it does not respond to it" do
      expect {AlteringClientExample.list}.to_not raise_error
    end

    it "should translate JSON returned through the Translator" do
      ret = AlteringClientExample.all
      expect(ret.first_name).to eq("Billy")
      expect(ret.name).to be_nil
    end

    it "should return original JSON for items that aren't handled by the Translator" do
      ret = AlteringClientExample.list
      expect(ret.name).to eq("Billy")
      expect(ret.first_name).to be_nil
    end
  end

  context "directly call a URL, rather than via a mapped method" do
    it "should be able to directly call a URL" do
      ActiveRestClient::Request.any_instance.should_receive(:do_request).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      EmptyExample._request("http://api.example.com/")
    end

    it "runs filters as usual" do
      ActiveRestClient::Request.any_instance.should_receive(:do_request).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      EmptyExample.should_receive(:_filter_request).with(any_args)
      EmptyExample._request("http://api.example.com/")
    end

    it "should make an HTTP request" do
      ActiveRestClient::Connection.any_instance.should_receive(:get).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      EmptyExample._request("http://api.example.com/")
    end

    it "should map the response from the directly called URL in the normal way" do
      ActiveRestClient::Request.any_instance.should_receive(:do_request).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      example = EmptyExample._request("http://api.example.com/")
      expect(example.first_name).to eq("Billy")
    end

    it "should be able to pass the plain response from the directly called URL bypassing JSON loading" do
      response = OpenStruct.new(_status:200, body:"This is another non-JSON string")
      ActiveRestClient::Connection.any_instance.should_receive(:post).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:response))
      expect(EmptyExample._plain_request("http://api.example.com/", :post, {id:1234})).to eq(response)
    end

    it "should cache plain requests separately" do
      perform_caching = EmptyExample.perform_caching
      cache_store = EmptyExample.cache_store
      begin
        response = OpenStruct.new(_status:200, body:"This is a non-JSON string")
        other_response = OpenStruct.new(_status:200, body:"This is another non-JSON string")
        allow_any_instance_of(ActiveRestClient::Connection).to receive(:get) do |url, others|
          if url == "/?test=1"
            OpenStruct.new(status:200, headers:{}, body:response)
          else
            OpenStruct.new(status:200, headers:{}, body:other_response)
          end
        end
        EmptyExample.perform_caching = true
        EmptyExample.cache_store = TestCacheStore.new
        expect(EmptyExample._plain_request("http://api.example.com/?test=1")).to eq(response)
        expect(EmptyExample._plain_request("http://api.example.com/?test=2")).to eq(other_response)
      ensure
        EmptyExample.perform_caching = perform_caching
        EmptyExample.cache_store = cache_store
      end
    end

    it "should be able to lazy load a direct URL request" do
      ActiveRestClient::Request.any_instance.should_receive(:do_request).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      example = EmptyExample._lazy_request("http://api.example.com/")
      expect(example).to be_an_instance_of(ActiveRestClient::LazyLoader)
      expect(example.first_name).to eq("Billy")
    end

    it "should be able to specify a method and parameters for the call" do
      ActiveRestClient::Connection.any_instance.should_receive(:post).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      EmptyExample._request("http://api.example.com/", :post, {id:1234})
    end

    it "should be able to use mapped methods to create a request to pass in to _lazy_request" do
      ActiveRestClient::Connection.any_instance.should_receive(:get).with('/find/1', anything).and_return(OpenStruct.new(status:200, headers:{}, body:"{\"first_name\":\"Billy\"}"))
      request = AlteringClientExample._request_for(:find, :id => 1)
      example = AlteringClientExample._lazy_request(request)
      expect(example.first_name).to eq("Billy")
    end
  end

  context "Recording a response" do
    it "calls back to the record_response callback with the url and response body" do
      ActiveRestClient::Connection.any_instance.should_receive(:get).with(any_args).and_return(OpenStruct.new(status:200, headers:{}, body:"Hello world"))
      expect{RecordResponseExample.all}.to raise_error(Exception, "/all|Hello world")
    end
  end

  context "JSON output" do
    let(:student1) { EmptyExample.new(name:"John Smith", age:31) }
    let(:student2) { EmptyExample.new(name:"Bob Brown", age:29) }
    let(:location) { EmptyExample.new(place:"Room 1408") }
    let(:lazy) { Laz }
    let(:object) { EmptyExample.new(name:"Programming 101", location:location, students:[student1, student2]) }
    let(:json_parsed_object) { Oj.load(object.to_json) }

    it "should be able to export to valid json" do
      expect(object.to_json).to_not be_blank
      expect{Oj.load(object.to_json)}.to_not raise_error
    end

    it "should not be using Object's #to_json method" do
      expect(json_parsed_object["dirty_attributes"]).to be_nil
    end

    it "should recursively convert nested objects" do
      expect(json_parsed_object["location"]["place"]).to eq(location.place)
    end

    it "should include arrayed objects" do
      expect(json_parsed_object["students"]).to be_an_instance_of(Array)
      expect(json_parsed_object["students"].size).to eq(2)
      expect(json_parsed_object["students"].first["name"]).to eq(student1.name)
      expect(json_parsed_object["students"].second["name"]).to eq(student2.name)
    end

    it "should set integers as a native JSON type" do
      expect(json_parsed_object["students"].first["age"]).to eq(student1.age)
      expect(json_parsed_object["students"].second["age"]).to eq(student2.age)
    end

  end

end
