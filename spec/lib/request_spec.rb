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
      get :babies, "/babies", :has_many => {:children => ExampleOtherClient}
      get :headers, "/headers"
      get :find, "/:id"
      post :create, "/create"
      put :update, "/put/:id"
      delete :remove, "/remove/:id"
      get :hal, "/hal", fake:"{\"_links\":{\"child\": {\"href\": \"/child/1\"}, \"other\": {\"href\": \"/other/1\"}, \"cars\":[{\"href\": \"/car/1\", \"name\":\"car1\"}, {\"href\": \"/car/2\", \"name\":\"car2\"}, {\"href\": \"/car/not-embed\", \"name\":\"car_not_embed\"} ], \"lazy\": {\"href\": \"/lazy/load\"}, \"invalid\": [{\"href\": \"/invalid/1\"}]}, \"_embedded\":{\"other\":{\"name\":\"Jane\"},\"child\":{\"name\":\"Billy\"}, \"cars\":[{\"_links\": {\"self\": {\"href\": \"/car/1\"} }, \"make\": \"Bugatti\", \"model\": \"Veyron\"}, {\"_links\": {\"self\": {\"href\": \"/car/2\"} }, \"make\": \"Ferrari\", \"model\": \"F458 Italia\"} ], \"invalid\": [{\"present\":true, \"_links\": {} } ] } }", has_many:{other:ExampleOtherClient}
      get :fake, "/fake", fake:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"child\":{\"grandchild\":{\"test\":true}}}"
      get :defaults, "/defaults", defaults:{overwrite:"no", persist:"yes"}
    end

    class LazyLoadedExampleClient < ExampleClient
      lazy_load!
      get :fake, "/fake", fake:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"child\":{\"grandchild\":{\"test\":true}}}"
      get :lazy_test, "/does-not-matter", fake:"{\"people\":[\"http://www.example.com/some/url\"]}", :lazy => [:people]
    end

    class VerboseExampleClient < ExampleClient
      verbose!
      get :all, "/all"
    end

    class FilteredBodyExampleClient < ExampleClient
      base_url "http://www.example.com"
      before_request do |name, request|
        request.body = Oj.dump(request.post_params)
      end

      post :save, "/save"
    end

    ActiveRestClient::Request.any_instance.stub(:read_cached_response)
  end

  it "should get an HTTP connection when called" do
    connection = double(ActiveRestClient::Connection).as_null_object
    ActiveRestClient::ConnectionManager.should_receive(:get_connection).and_return(connection)
    connection.should_receive(:get).with("/", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all
  end

  it "should get an HTTP connection when called and call get on it" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all
  end

  it "should get an HTTP connection when called and call delete on it" do
    ActiveRestClient::Connection.any_instance.should_receive(:delete).with("/remove/1", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.remove(id:1)
  end

  it "should pass through get parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/?debug=true", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.all debug:true
  end

  it "should pass through get parameters, using defaults specified" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/defaults?overwrite=yes&persist=yes", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.defaults overwrite:"yes"
  end

  it "should pass through url parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.find id:1234
  end

  it "should accept an integer as the only parameter and use it as id" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.find(1234)
  end

  it "should accept a string as the only parameter and use it as id" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.find("1234")
  end

  it "should pass through url parameters and get parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/1234?debug=true", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", headers:{}))
    ExampleClient.find id:1234, debug:true
  end

  it "should pass through url parameters and put parameters" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", headers:{}))
    ExampleClient.update id:1234, debug:true
  end

  it "should pass through custom headers" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/headers", hash_including("X-My-Header" => "myvalue")).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
    ExampleClient.headers
  end

  it "should parse JSON to give a nice object" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true, \"list\":[1,2,3,{\"test\":true}], \"created_at\":\"2012-03-04T01:02:03Z\", \"child\":{\"grandchild\":{\"test\":true}}}", headers:{}))
    object = ExampleClient.update id:1234, debug:true
    expect(object.result).to eq(true)
    expect(object.list.first).to eq(1)
    expect(object.list.last.test).to eq(true)
    expect(object.created_at).to be_an_instance_of(DateTime)
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
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/put/1234", "debug=true", an_instance_of(Hash)).and_return(OpenStruct.new(body:"[{\"first_name\":\"Johnny\"}, {\"first_name\":\"Billy\"}]", status:200, headers:{}))
    object = ExampleClient.update id:1234, debug:true
    expect(object).to be_instance_of(ActiveRestClient::ResultIterator)
    expect(object.first.first_name).to eq("Johnny")
    expect(object[1].first_name).to eq("Billy")
    expect(object._status).to eq(200)
  end

  it "should instantiate other classes using has_many when required to do so" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"first_name\":\"Johnny\", \"expenses\":[{\"amount\":1}, {\"amount\":2}]}", status:200, headers:{}))
    object = ExampleClient.all
    expect(object.expenses.first).to be_instance_of(ExampleOtherClient)
  end

  it "should instantiate other classes using has_many even if nested off the root" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/babies", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"first_name\":\"Johnny\", \"children\":{\"eldest\":[{\"name\":\"Billy\"}]}}", status:200, headers:{}))
    object = ExampleClient.babies
    expect(object.children.eldest.first).to be_instance_of(ExampleOtherClient)
  end

  it "should assign new attributes to the existing object if possible" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
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
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
    ActiveRestClient::Logger.should_receive(:info).with {|*args| args.first[%r{Requesting http://www.example.com/create}]}
    ActiveRestClient::Logger.should_receive(:debug).at_least(1).times.with {|*args| args.first[/Response received \d+ bytes/] || args.first["Reading from cache"]}

    object = ExampleClient.new(first_name:"John", should_disappear:true)
    object.create
    expect(object._status).to eq(200)
  end

  it "should debug log 200 responses" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
    ActiveRestClient::Logger.should_receive(:info).with {|*args| args.first[%r{Requesting http://www.example.com/create}]}
    ActiveRestClient::Logger.should_receive(:debug).at_least(1).times.with {|*args| args.first[/Response received \d+ bytes/] || args.first["Reading from cache"]}

    object = ExampleClient.new(first_name:"John", should_disappear:true)
    object.create
  end

  it "should verbose log if enabled" do
    connection = double(ActiveRestClient::Connection).as_null_object
    ActiveRestClient::ConnectionManager.should_receive(:get_connection).and_return(connection)
    connection.should_receive(:get).with("/all", an_instance_of(Hash)).and_return(OpenStruct.new(body:'{"result":true}', headers:{"Content-Type" => "application/json", "Connection" => "close"}))
    ActiveRestClient::Logger.should_receive(:debug).with("ActiveRestClient Verbose Log:")
    ActiveRestClient::Logger.should_receive(:debug).with(/ > /).at_least(:twice)
    ActiveRestClient::Logger.should_receive(:debug).with(/ < /).at_least(:twice)
    ActiveRestClient::Logger.stub(:debug).with(any_args)
    VerboseExampleClient.all
  end

  it "should raise an unauthorised exception for 401 errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:401))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPUnauthorisedClientException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPUnauthorisedClientException)
    expect(e.status).to eq(401)
    expect(e.result.first_name).to eq("John")
  end

  it "should raise a forbidden client exception for 403 errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:403))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPForbiddenClientException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPForbiddenClientException)
    expect(e.status).to eq(403)
  expect(e.result.first_name).to eq("John")
  end

  it "should raise a not found client exception for 404 errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:404))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPNotFoundClientException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPNotFoundClientException)
    expect(e.status).to eq(404)
    expect(e.result.first_name).to eq("John")
  end

  it "should raise a client exceptions for 4xx errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
      and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:409))
    object = ExampleClient.new(first_name:"John", should_disappear:true)
    begin
      object.create
    rescue ActiveRestClient::HTTPClientException => e
      e
    end
    expect(e).to be_instance_of(ActiveRestClient::HTTPClientException)
    expect(e.status).to eq(409)
  expect(e.result.first_name).to eq("John")
  end

  it "should raise a server exception for 5xx errors" do
    ActiveRestClient::Connection.
      any_instance.
      should_receive(:post).
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
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
      with("/create", "first_name=John&should_disappear=true", an_instance_of(Hash)).
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
      def verbose ; false ; end
    end
    fake_object = RequestFakeObject.new
    request = ActiveRestClient::Request.new(method, fake_object, {})
    allow(fake_object).to receive(:read_cached_response).and_return(nil)
    expect{request.call}.to raise_error(ActiveRestClient::InvalidRequestException)
  end

  it "should send all class mapped methods through _filter_request" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"first_name\":\"Johnny\", \"expenses\":[{\"amount\":1}, {\"amount\":2}]}", status:200, headers:{}))
    ExampleClient.should_receive(:_filter_request).with(any_args)
    ExampleClient.all
  end

  it "should send all instance mapped methods through _filter_request" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{\"first_name\":\"Johnny\", \"expenses\":[{\"amount\":1}, {\"amount\":2}]}", status:200, headers:{}))
    ExampleClient.should_receive(:_filter_request).with(any_args)
    e = ExampleClient.new
    e.all
  end

  context "Direct URL requests" do
    class SameServerExampleClient < ActiveRestClient::Base
      URL = "http://www.example.com/some/url"
      base_url "http://www.example.com/v1"
      get :same_server, "/does-not-matter", url:URL
    end

    class OtherServerExampleClient < ActiveRestClient::Base
      URL = "http://other.example.com/some/url"
      base_url "http://www.example.com/v1"
      get :other_server, "/does-not-matter", url:URL
    end

    it "should allow requests directly to URLs" do
      ActiveRestClient::ConnectionManager.reset!
      ActiveRestClient::Connection.
        any_instance.
        should_receive(:get).
        with("/some/url", an_instance_of(Hash)).
        and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
      SameServerExampleClient.same_server
    end

    it "should allow requests directly to URLs even if to different URLs" do
      ActiveRestClient::ConnectionManager.reset!
      connection = double("Connection")
      connection.
        should_receive(:get).
        with("/some/url", an_instance_of(Hash)).
        and_return(OpenStruct.new(body:"", headers:{}, status:304))
      connection.
        stub(:base_url).
        and_return("http://other.example.com")
      ActiveRestClient::ConnectionManager.should_receive(:find_connection_for_url).with(OtherServerExampleClient::URL).and_return(connection)
      OtherServerExampleClient.other_server
    end

    it "should allow requests to partial URLs using the current base_url" do
      ActiveRestClient::ConnectionManager.reset!
      connection = double("Connection").as_null_object
      ActiveRestClient::ConnectionManager.should_receive(:get_connection).with("http://www.example.com").and_return(connection)
      connection.
        should_receive(:get).
        with("/people", an_instance_of(Hash)).
        and_return(OpenStruct.new(body:"{\"first_name\":\"John\", \"id\":1234}", headers:{}, status:200))
      @obj = SameServerExampleClient._request('/people')
    end
  end

  # HAL is Hypermedia Application Language
  context "HAL" do
    let(:hal) { ExampleClient.hal }

    it "should request a HAL response or plain JSON" do
      ActiveRestClient::Connection.any_instance.should_receive(:get).with("/headers", hash_including("Accept" => "application/hal+json, application/json;q=0.5")).and_return(OpenStruct.new(body:'{"result":true}', headers:{}))
      ExampleClient.headers
    end

    it "should recognise a HAL response" do
      method = {:method => :get, url:"/"}
      class RequestFakeObject
        def base_url
          "http://www.example.com/"
        end

        def name ; end
        def _filter_request(*args) ; end
      end
      fake_object = RequestFakeObject.new
      request = ActiveRestClient::Request.new(method, fake_object, {})
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => "application/hal+json"}))
      expect(request.hal_response?).to be_true
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => "application/json"}))
      expect(request.hal_response?).to be_true
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => "text/plain"}))
      expect(request.hal_response?).to be_false
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => ["text/plain", "application/hal+json"]}))
      expect(request.hal_response?).to be_true
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => ["text/plain", "application/json"]}))
      expect(request.hal_response?).to be_true
      request.instance_variable_set(:@response, OpenStruct.new(headers:{"Content-Type" => ["text/plain"]}))
      expect(request.hal_response?).to be_false
    end

    it "should map _links in to the normal attributes" do
      expect(hal.child).to be_an_instance_of(ExampleClient)
      expect(hal.cars.size).to eq(3)
    end

    it "should be able to use other attributes of _links using _hal_attributes method with a key" do
      expect(hal.child).to be_an_instance_of(ExampleClient)
      expect(hal.cars[2]._hal_attributes("name")).to eq('car_not_embed')
    end

    it "should use _embedded responses instead of lazy loading if possible" do
      expect(hal.child.name).to eq("Billy")
      expect(hal.cars.first.make).to eq("Bugatti")
    end

    it "should instantiate other classes defined using has_many when using _embedded responses" do
      expect(hal.other).to be_an(ExampleOtherClient)
    end

    it "should convert invalid _embedded responses in to lazy loading on error" do
      expect(hal.invalid.first).to be_an_instance_of(ActiveRestClient::LazyAssociationLoader)
    end

    it "should lazy load _links attributes if not embedded" do
      expect(hal.lazy).to be_an_instance_of(ActiveRestClient::LazyAssociationLoader)
      expect(hal.lazy.instance_variable_get(:@url)).to eq("/lazy/load")
    end
  end

  it "replaces the body completely in a filter" do
    ActiveRestClient::Connection.any_instance.should_receive(:post).with("/save", "{\":id\":1234,\":name\":\"john\"}", an_instance_of(Hash)).and_return(OpenStruct.new(body:"{}", headers:{}))
    FilteredBodyExampleClient.save id:1234, name:'john'
  end
end
