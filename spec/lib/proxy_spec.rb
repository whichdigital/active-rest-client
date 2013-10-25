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

  put "/change-format" do
    response = passthrough
    translate(response) do |body|
      body["first_name"] = body.delete("fname")
      body
    end
  end

  put "/fake" do
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
  get :change_format, "/change-format"
  post :create, "/create"
  put :update, "/update"
  get :not_proxied, "/not_proxied"
end

describe ActiveRestClient::Base do
  it "allows the URL to be changed" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/getAll?id=1", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.all(id:1)
  end

  it "allows the URL to be replaced" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/new", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.old
  end

  it "has access to the GET params and allow them to be changed/removed/added" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/list?age=12&first_name=John", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.list(fname:"John", lname:"Smith")
  end

  it "has access to the POST params and allow them to be changed/removed/added" do
    ActiveRestClient::Connection.any_instance.should_receive(:post).with("/create", {age:12, first_name:"John"}.to_query, instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.create(fname:"John", lname:"Smith")
  end

  it "has access to raw body content for requests" do
    ActiveRestClient::Connection.any_instance.should_receive(:put).with("/update", "MY-BODY-CONTENT", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.update(fname:"John", lname:"Smith")
  end

  it "can return fake JSON data and have this parsed in the normal way" do
    ActiveRestClient::Connection.any_instance.should_not_receive(:get).with("/fake", instance_of(Hash))
    ret = ProxyClientExample.fake
    expect(ret.id).to eq(1234)
  end

  it "can intercept the response and parse the response, alter it and pass it on during the request" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/change-format", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"fname\":\"Billy\"}", status:200, headers:{}))
    ret = ProxyClientExample.change_format
    expect(ret.first_name).to eq("Billy")
  end

  it "can continue with the request in the normal way, passing it on to the server" do
    ActiveRestClient::Connection.any_instance.should_receive(:get).with("/not_proxied?id=1", instance_of(Hash)).and_return(OpenStruct.new(body:"{\"result\":true}", status:200, headers:{}))
    ProxyClientExample.not_proxied(id:1)
  end
end
