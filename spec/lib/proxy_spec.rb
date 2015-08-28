require 'spec_helper'
require 'active_support/core_ext/hash'

class ProxyExample < ActiveRestClient::ProxyBase
  get "/all" do
    url.gsub!("/all", "/getAll")
    passthrough
  end

  get "/old" do
    url "/new"
    passthrough
  end

  get "/list" do
    get_params[:first_name] = get_params.delete(:fname)
    get_params[:age] = 12
    get_params.delete(:lname)
    passthrough
  end

  post "/create" do
    post_params[:first_name] = post_params.delete(:fname)
    post_params[:age] = 12
    post_params.delete(:lname)
    passthrough
  end

  put "/update" do
    body "MY-BODY-CONTENT"
    passthrough
  end

  delete '/remove' do
    passthrough
  end

  get "/change-format" do
    response = passthrough
    translate(response) do |body|
      body["first_name"] = body.delete("fname")
      body
    end
  end

  get "/change-xml-format" do
    response = passthrough
    translate(response) do |body|
      body["first_name"] = body["object"].delete("fname")
      body
    end
  end

  get "/hal_test/:id" do
    response = passthrough
    translate(response) do |body|
      body["_links"] = {"test" => {href:"/this/is/a/test"}}
      body
    end
  end

  get "/param/:id/:name" do
    render "{\"id\":\"#{params[:id]}\", \"name\":\"#{params[:name]}\"}"
  end

  get "/fake" do
    render "{\"id\":1234}"
  end
end

class ProxyClientExample < ActiveRestClient::Base
  proxy ProxyExample
  base_url "http://www.example.com"

  get :all, "/all"
  get :old, "/old"
  get :list, "/list"
  get :fake, "/fake"
  get :param, "/param/:id/:name"
  get :change_format, "/change-format"
  get :change_xml_format, "/change-xml-format"
  post :create, "/create"
  put :update, "/update"
  get :not_proxied, "/not_proxied"
  delete :remove, "/remove"
  get :hal_test, "/hal_test/:id"
end

describe ActiveRestClient::Base do
  it "allows the URL to be changed" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/getAll?id=1", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.all(id:1)
  end

  it "allows the URL to be replaced" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/new", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.old
  end

  it "has access to the GET params and allow them to be changed/removed/added" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/list?age=12&first_name=John", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.list(fname:"John", lname:"Smith")
  end

  it "has access to the POST params and allow them to be changed/removed/added" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:post).with("/create", {age:12, first_name:"John"}.to_query, instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.create(fname:"John", lname:"Smith")
  end

  it "has access to raw body content for requests" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:put).with("/update", "MY-BODY-CONTENT", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{})))
    ProxyClientExample.update(fname:"John", lname:"Smith")
  end

  it "handles DELETE requests" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:delete).with("/remove", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{})))
    ProxyClientExample.remove
  end

  it "can return fake JSON data and have this parsed in the normal way" do
    expect_any_instance_of(ActiveRestClient::Connection).not_to receive(:get).with("/fake", instance_of(Hash))
    ret = ProxyClientExample.fake
    expect(ret.id).to eq(1234)
  end

  it "can intercept the response and parse the response, alter it and pass it on during the request" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/change-format", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"fname\":\"Billy\"}", status:200, response_headers:{})))
    ret = ProxyClientExample.change_format
    expect(ret.first_name).to eq("Billy")
  end

  it "can intercept XML responses, parse the response, alter it and pass it on during the request" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/change-xml-format",
      instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(
      body:"<?xml version=\"1.0\" encoding=\"UTF-8\"?><object><fname>Billy</fname></object>",
      status:200,
      response_headers:{"Content-Type" => "application/xml"})))
    ret = ProxyClientExample.change_xml_format
    expect(ret.first_name).to eq("Billy")
  end

  it 'skips the altering of the response body when there is none' do
    allow_any_instance_of(ActiveRestClient::Connection).to receive(:get).with('/change-format', instance_of(Hash))
      .and_return(double(body: '', status: 200, headers: {}))
    result = ProxyClientExample.change_format
    expect(result._attributes).to be_empty
  end

  it "can continue with the request in the normal way, passing it on to the server" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/not_proxied?id=1", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{})))
    ProxyClientExample.not_proxied(id:1)
  end

  it "caches responses in the standard way" do

     cached_response = ActiveRestClient::CachedResponse.new(
        status:200,
        result:@cached_object,
        etag:@etag)

    cache_store = double("CacheStore")
    allow(cache_store).to receive(:read).with(any_args).and_return(nil)
    ProxyClientExample.perform_caching true
    allow(ProxyClientExample).to receive(:cache_store).and_return(cache_store)
    expiry = 10.minutes.from_now.rfc2822
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:put).with("/update", "MY-BODY-CONTENT", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{"Expires" => expiry, "ETag" => "123456"})))
    expect(ProxyClientExample.cache_store).to receive(:write) do |key, object, options|
      expect(key).to eq("ProxyClientExample:/update")
      expect(object).to be_an_instance_of(String)
      unmarshalled = Marshal.load(object)
      expect(unmarshalled.etag).to eq("123456")
      expect(unmarshalled.expires).to eq(expiry)
    end
    ProxyClientExample.update(id:1)
  end

  it "can have parameters in the URL" do
    ret = ProxyClientExample.param(id:1234, name:"Johnny")
    expect(ret.id).to eq("1234")
    expect(ret.name).to eq("Johnny")
  end

  it "can force the URL from a filter without it being passed through URL replacement" do
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/hal_test/1", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{})))
    expect_any_instance_of(ActiveRestClient::Connection).to receive(:get).with("/this/is/a/test", instance_of(Hash)).and_return(::FaradayResponseMock.new(OpenStruct.new(body:"{\"result\":true}", status:200, response_headers:{})))
    expect(ProxyClientExample.hal_test(id:1).test.result).to eq(true)
  end

end
