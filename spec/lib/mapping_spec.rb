require 'spec_helper'

class MappingExample
  include ActiveRestClient::Mapping

  get :get, "/get", tag:1
  put :put, "/put", tag:2
  post :post, "/post", tag:3
  delete :delete, "/delete", tag:4
end

describe ActiveRestClient::Mapping do
  it "should support methods for get/put/post/delete for mapping" do
    expect(EmptyExample).to respond_to(:get)
    expect(EmptyExample).to respond_to(:put)
    expect(EmptyExample).to respond_to(:post)
    expect(EmptyExample).to respond_to(:delete)
  end

  it "should save URL for each mapped call" do
    expect(MappingExample._calls[:get][:url]).to eq("/get")
    expect(MappingExample._calls[:put][:url]).to eq("/put")
    expect(MappingExample._calls[:post][:url]).to eq("/post")
    expect(MappingExample._calls[:delete][:url]).to eq("/delete")
  end

  it "should save the correct method type for each mapped call" do
    expect(MappingExample._calls[:get][:method]).to eq(:get)
    expect(MappingExample._calls[:put][:method]).to eq(:put)
    expect(MappingExample._calls[:post][:method]).to eq(:post)
    expect(MappingExample._calls[:delete][:method]).to eq(:delete)
  end

  it "should remember options set for each mapped call" do
    expect(MappingExample._calls[:get][:options][:tag]).to eq(1)
    expect(MappingExample._calls[:put][:options][:tag]).to eq(2)
    expect(MappingExample._calls[:post][:options][:tag]).to eq(3)
    expect(MappingExample._calls[:delete][:options][:tag]).to eq(4)
  end
end
