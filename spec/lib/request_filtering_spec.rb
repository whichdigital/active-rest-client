require 'spec_helper'

class RequestFilteringExample
  include ActiveRestClient::RequestFiltering

  before_request do |name, request|
    request.get_params[:filter1] = "Hello"
  end

  before_request do |name, request|
    request.post_params[:post_filter1] = "World"
  end

  before_request do |name, request|
    request.headers["X-My-Header"] = "myvalue"
  end

  before_request :set_to_ssl
  before_request :set_via_instance

  after_request :change_body

  private

  def self.set_to_ssl(name, request)
    request.url.gsub!("http://", "https://")
  end

  def set_via_instance(name, request)
    request.url.gsub!("//www", "//new")
  end

  def change_body(name, response)
    response.body = "{test: 1}"
  end
end

class SubClassedRequestFilteringExample < RequestFilteringExample
  before_request do |name, request|
    request.get_params[:api_key] = 1234
  end
end

describe ActiveRestClient::RequestFiltering do
  let(:request) { OpenStruct.new(get_params:{}, post_params:{}, url:"http://www.example.com", headers:ActiveRestClient::HeadersList.new) }
  let(:response) { OpenStruct.new(body:"") }

  it "should call through to adjust the parameters" do
    RequestFilteringExample._filter_request(:before, :test, request)
    expect(request.get_params).to have_key(:filter1)
  end

  it "should call through for more than one filter" do
    RequestFilteringExample._filter_request(:before, :test, request)
    expect(request.get_params).to have_key(:filter1)
    expect(request.post_params).to have_key(:post_filter1)
  end

  it "should allow adjusting the URL via a named filter" do
    RequestFilteringExample._filter_request(:before, :test, request)
    expect(request.url).to match(/https:\/\//)
  end

  it "should allow adjusting the URL via a named filter as an instance method" do
    RequestFilteringExample._filter_request(:before, :test, request)
    expect(request.url).to match(/\/\/new\./)
  end

  it "should allow filters to be set on the parent or on the child" do
    SubClassedRequestFilteringExample._filter_request(:before, :test, request)
    expect(request.url).to match(/\/\/new\./)
    expect(request.get_params[:api_key]).to eq(1234)
  end

  it "should allow filters to add custom headers" do
    RequestFilteringExample._filter_request(:before, :test, request)
    expect(request.headers["X-My-Header"]).to eq("myvalue")
  end

  it "should be able to alter the response body" do
    RequestFilteringExample._filter_request(:after, :test, response)
    expect(response.body).to eq("{test: 1}")
  end
end
