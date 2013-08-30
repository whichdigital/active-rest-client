require 'spec_helper'

describe ActiveRestClient::Request do
  before :each do
    class ExampleOtherClient < ActiveRestClient::Base ; end
    class ExampleClient < ActiveRestClient::Base
      base_url "http://www.example.com"

      before_request do |name, request|
        if request.method[:name] == :headers
          request.headers["X-My-Header"] = "myvalue"
        end
      end

      get :all, "/", :has_many => {:expenses => ExampleOtherClient}
      get :headers, "/headers"
      get :find, "/:id"
      post :create, "/create"
      put :update, "/put/:id"
      delete :remove, "/remove/:id"
      get :fake, "/fake", fake:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"child\":{\"grandchild\":{\"test\":true}}}"
      get :defaults, "/defaults", defaults:{overwrite:"no", persist:"yes"}
      get :lazy_test, "/does-not-matter", fake:"{\"people\":[\"http://www.example.com/some/url\"]}", :lazy => %i{people}
    end
    class LazyLoadedExampleClient < ExampleClient
      lazy_load!
    end

    ActiveRestClient::Request.any_instance.stub(:read_cached_response)
  end

  it "should get an HTTP connection when called" do
    connection = double(ActiveRestClient::Connection).as_null_object
    ActiveRestClient::ConnectionManager.should_receive(:get_connection).and_return(connection)
    connection.should_receive(:get).with("/", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all
  end

  it "should get an HTTP connection when called and call get on it" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all
  end

  it "should get an HTTP connection when called and call delete on it" do
    ActiveRestClient::Connection.any_instance.should_receive(:delete).with("/remove/1", "", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.remove(id:1)
  end

  it "should pass through get parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/?debug=true", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all debug:true
  end

  it "should pass through get parameters, using defaults specified" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/defaults?overwrite=yes&persist=yes", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.defaults overwrite:"yes"
  end

  it "should pass through url parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234", {}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.find id:1234
  end

  it "should pass through url parameters and get parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234?debug=true", {}).and_return(OpenStruct.new(body:"{\"result\":true}", headers:{}))
    ExampleClient.find id:1234, debug:true
  end

  it "should pass through url parameters and put parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", {}).and_return(OpenStruct.new(body:"{\"result\":true}", headers:{}))
    ExampleClient.update id:1234, debug:true
  end

  it "should pass through custom headers" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/headers", {"X-My-Header" => "myvalue"}).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.headers
  end

  it "should parse JSON to give a nice object" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", {}).and_return(OpenStruct.new(body:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"child\":{\"grandchild\":{\"test\":true}}}", headers:{}))
    object = ExampleClient.update id:1234, debug:true
    expect(object.result).to eq(true)
    expect(object.list.first).to eq(1)
    expect(object.list.last.test).to eq(true)
    expect(object.child.grandchild.test).to eq(true)
  end

  it "should parse JSON and return a nice object for faked responses" do
    object = ExampleClient.fake id:1234, debug:true
    expect(object.result).to eq(true)
    expect(object.list.first).to eq(1)
    expect(object.list.last.test).to eq(true)
    expect(object.child.grandchild.test).to eq(true)
  end

  it "should return a lazy loader object if lazy loading is enabled" do
    object = LazyLoadedExampleClient.fake id:1234, debug:true
    expect(object).to be_an_instance_of(ActiveRestClient::LazyLoader)
  end

  it "should proxy through nice object for lazy loaded responses" do
    object = LazyLoadedExampleClient.fake id:1234, debug:true
    expect(object.result).to eq(true)
    expect(object.list.first).to eq(1)
    expect(object.list.last.test).to eq(true)
    expect(object.child.grandchild.test).to eq(true)
  end

  it "should return a LazyAssociationLoader for lazy loaded properties" do
    object = LazyLoadedExampleClient.lazy_test
    expect(object.people.size).to eq(1)
    expect(object.people).to be_an_instance_of(ActiveRestClient::LazyAssociationLoader)
  end

  it "should log faked responses" do
    ActiveRestClient::Logger.stub(:debug)
    ActiveRestClient::Logger.should_receive(:debug).with {|*args| args.first["Faked response found"]}
    object = ExampleClient.fake id:1234, debug:true
  end

  it "should parse an array within JSON to be a result iterator" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", {}).and_return(OpenStruct.new(body:"[{\"first_name\":\"Johnny\"}, {\"first_name\":\"Billy\"}]", status:200, headers:{}))
    object = ExampleClient.update id:1234, debug:true
    expect(object).to be_instance_of(ActiveRestClient::ResultIterator)
    expect(object.first.first_name).to eq("Johnny")
    expect(object[1].first_name).to eq("Billy")
    expect(object._status).to eq(200)
  end

  it "should instantiate other classes using has_many when required to do so" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", {}).and_return(OpenStruct.new(body:"{\"first_name\":\"Johnny\", \"expenses\":[{\"amount\":1}, {\"amount\":2}]}", status:200, headers:{}))
    object = ExampleClient.all
    expect(object.expenses.first).to be_instance_of(ExampleOtherClient)
  end

  it "should assign new attributes to the existing object if possible" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    object.create
    expect(object.first_name).to eq("John")
    expect(object.should_disappear).to eq(nil)
    expect(object.id).to eq(1234)
  end

  it "should clearly pass through 200 status responses" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
    ActiveRestClient::Logger.should_receive(:info).with {|*args| args.first[%r{Requesting http://www.example.com/create}]}
    ActiveRestClient::Logger.should_receive(:debug).with {|*args| args.first[/Response received \d+ bytes/]}

    object = ExampleClient.new(first_name:"John", should_disappear:true)
    object.create
    expect(object._status).to eq(200)
  end

  it "should debug log 200 responses" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
    ActiveRestClient::Logger.should_receive(:info).with {|*args| args.first[%r{Requesting http://www.example.com/create}]}
    ActiveRestClient::Logger.should_receive(:debug).with {|*args| args.first[/Response received \d+ bytes/]}

    object = ExampleClient.new(first_name:"John", should_disappear:true)
    object.create
  end

  it "should raise a client exceptions for 4xx errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:404))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPClientException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPClientException)
    expect(e.status).to eq(404)
  expect(e.result.first_name).to eq("John")
  end

  it "should raise a server exception for 5xx errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:500))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPServerException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPServerException)
    expect(e.status).to eq(500)
    expect(e.result.first_name).to eq("John")
  end

  it "should raise a parse exception for invalid JSON returns" do
    error_content = "<h1>500 Server Error</h1>"
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", {}).
      and_return(OpenStruct.new(body:error_content, headers:{}, status:500))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::ResponseParseException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::ResponseParseException)
    expect(e.status).to eq(500)
    expect(e.body).to eq(error_content)
  end

  it "should raise an exception if you try to pass in an unsupport method" do
    method = {:method => :wiggle, url:"/"}
    class RequestFakeObject
      def base_url
        "http://www.example.com/"
      end

      def name ; end
      def _filter_request(*args) ; end
    end
    fake_object = RequestFakeObject.new
    request = ActiveRestClient::Request.new(method, fake_object, {})
    expect{request.call}.to raise_error(ActiveRestClient::InvalidRequestException)
  end

  context "Direct URL requests" do
    class SameServerExampleClient < ActiveRestClient::Base
      URL = "http://www.example.com/some/url"
      base_url "http://www.example.com"
      get :same_server, "/does-not-matter", url:URL
    end

    class OtherServerExampleClient < ActiveRestClient::Base
      URL = "http://other.example.com/some/url"
      base_url "http://www.example.com"
      get :other_server, "/does-not-matter", url:URL
    end

    it "should allow requests directly to URLs" do
      ActiveRestClient::ConnectionManager.reset!
      ActiveRestClient::Connection.
        any_instance.
        should_receive(:get).
        with("/some/url", {}).
        and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
      SameServerExampleClient.same_server
    end

    it "should allow requests directly to URLs even if to different URLs" do
      ActiveRestClient::ConnectionManager.reset!
      connection = double("Connection")
      connection.
        should_receive(:get).
        with("/some/url", {}).
        and_return(OpenStruct.new(body:"", headers:{}, status:304))
      connection.
        should_receive(:base_url).
        any_number_of_times.
        and_return("http://other.example.com")
      ActiveRestClient::ConnectionManager.should_receive(:find_connection_for_url).with(OtherServerExampleClient::URL).and_return(connection)
      OtherServerExampleClient.other_server
    end

  end
end
