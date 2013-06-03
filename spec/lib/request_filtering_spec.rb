require 'spec_helper'

class RequestFilteringExample
  include ActiveRestClient::RequestFiltering

  before_request do |name, request|
    request.get_params[:filter1] = "Hello"
  end

  before_request do |name, request|
    request.post_params[:post_filter1] = "World"
  end

  before_request :set_to_ssl
  before_request :set_via_instance

  private

  def self.set_to_ssl(name, request)
    request.url.gsub!("http://", "https://")
  end

  def set_via_instance(name, request)
    request.url.gsub!("//www", "//new")
  end
end

describe ActiveRestClient::RequestFiltering do
  before(:each) do
    @request = OpenStruct.new(get_params:{}, post_params:{}, url:"http://www.example.com")
  end

  it "should call through to adjust the parameters" do
    RequestFilteringExample._filter_request(:test, @request)
    expect(@request.get_params).to have_key(:filter1)
  end

  it "should call through for more than one filter" do
    RequestFilteringExample._filter_request(:test, @request)
    expect(@request.get_params).to have_key(:filter1)
    expect(@request.post_params).to have_key(:post_filter1)
  end

  it "should allow adjusting the URL via a named filter" do
    RequestFilteringExample._filter_request(:test, @request)
    expect(@request.url).to match(/https:\/\//)
  end

  it "should allow adjusting the URL via a named filter as an instance method" do
    RequestFilteringExample._filter_request(:test, @request)
    expect(@request.url).to match(/\/\/new\./)
  end
end
