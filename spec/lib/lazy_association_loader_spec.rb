require 'spec_helper'

describe ActiveRestClient::LazyAssociationLoader do
  let(:url1) { "http://www.example.com/some/url" }
  let(:url2) { "http://www.example.com/some/other" }

  it "should raise an exception if you initialize it with a value that is not a string, hash or array" do
    expect do
      ActiveRestClient::LazyAssociationLoader.new(:person, OpenStruct.new, nil)
    end.to raise_error(ActiveRestClient::InvalidLazyAssociationContentException)
  end

  it "should store a URL passed as a string to the new object during creation" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, url1, nil)
    expect(loader.instance_variable_get(:@url)).to eq(url1)
  end

  it "should store a URL from a hash passed to the new object during creation" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, {"url" => url1}, nil)
    expect(loader.instance_variable_get(:@url)).to eq(url1)
  end

  it "should store a list of URLs from an array passed to the new object during creation" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, [url1, url2], nil)
    array = loader.instance_variable_get(:@subloaders)
    expect(array[0].instance_variable_get(:@url)).to eq(url1)
    expect(array[1].instance_variable_get(:@url)).to eq(url2)
    expect(array[2]).to be_nil
  end

  it "should report the size of a list of stored URLs" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, [url1, url2], nil)
    expect(loader.size).to eq(2)
  end

  it "should respond to each and iterate through the list of stored URLs" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, [url1, url2], nil)
    output = []
    loader.each do |o|
      output << o.instance_variable_get(:@url)
    end
    expect(output.size).to eq(2)
    expect(output[0]).to eq(url1)
    expect(output[1]).to eq(url2)
    expect(output[2]).to be_nil
  end

  it "should return a LazyAssociationLoader for each stored URL in a list" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, [url1, url2], nil)
    output = []
    loader.each do |o|
      expect(o).to be_an_instance_of(ActiveRestClient::LazyAssociationLoader)
    end
  end

  it "should make the request for a URL if it's accessed" do
    method_data = {options:{url:"foo"}}
    request = double("Request")
    request.should_receive(:method).any_number_of_times.and_return(method_data)
    request.should_receive(:method=).with(any_args).and_return(method_data)
    request.should_receive(:object).with(any_args).and_return(Array.new)
    request.should_receive(:call).with(any_args).and_return("")
    ActiveRestClient::Request.should_receive(:new).with(any_args).and_return(request)
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, url1, request)
    loader.length
  end

  it "should proxy methods to the underlying object if the request has been made" do
    loader = ActiveRestClient::LazyAssociationLoader.new(:person, url1, nil)
    object = double("Object")
    object.should_receive(:length).and_return(1)
    loader.instance_variable_set(:@object, object)
    expect(loader.length).to eq(1)
  end
end
