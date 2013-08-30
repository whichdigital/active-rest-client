require 'spec_helper'

class MappingExample
  include ActiveRestClient::Mapping
  get :test_get, "/get", tag:1, fake:"{result:true}", lazy:[:something]
  put :test_put, "/put", tag:2
  post :test_post, "/post", tag:3
  delete :test_delete, "/delete", tag:4
end

describe ActiveRestClient::Mapping do
  it "should support methods for get/put/post/delete for mapping" do
    expect(EmptyExample).to respond_to(:get)
    expect(EmptyExample).to respond_to(:put)
    expect(EmptyExample).to respond_to(:post)
    expect(EmptyExample).to respond_to(:delete)
  end

  it "should save URL for each mapped call" do
    expect(MappingExample._calls[:test_get][:url]).to eq("/get")
    expect(MappingExample._calls[:test_put][:url]).to eq("/put")
    expect(MappingExample._calls[:test_post][:url]).to eq("/post")
    expect(MappingExample._calls[:test_delete][:url]).to eq("/delete")
  end

  it "should save the correct method type for each mapped call" do
    expect(MappingExample._calls[:test_get][:method]).to eq(:get)
    expect(MappingExample._calls[:test_put][:method]).to eq(:put)
    expect(MappingExample._calls[:test_post][:method]).to eq(:post)
    expect(MappingExample._calls[:test_delete][:method]).to eq(:delete)
  end

  it "should remember options set for each mapped call" do
    expect(MappingExample._calls[:test_get][:options][:fake]).to eq("{result:true}")
    expect(MappingExample._calls[:test_get][:options][:lazy]).to eq([:something])
    expect(MappingExample._calls[:test_get][:options][:tag]).to eq(1)
    expect(MappingExample._calls[:test_put][:options][:tag]).to eq(2)
    expect(MappingExample._calls[:test_post][:options][:tag]).to eq(3)
    expect(MappingExample._calls[:test_delete][:options][:tag]).to eq(4)
  end

  it "should allow for mapped calls on the class" do
    expect(MappingExample).to respond_to(:test_get)
  end
end
