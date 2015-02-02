require 'spec_helper'

describe ActiveRestClient::LazyLoader do
  let(:request) { double("Request") }
  let(:response) { double("Response") }

  it "should not #call the passed in request during initialisation" do
    request.should_not_receive(:call)
    ActiveRestClient::LazyLoader.new(request)
  end

  it "should #call the passed in request if you check for response to a message" do
    request.should_receive(:call)
    loader = ActiveRestClient::LazyLoader.new(request)
    loader.respond_to?(:each)
  end

  it "should #call the passed in request if you call a method and pass through the method" do
    request.should_receive(:call).and_return(response)
    response.should_receive(:valid).and_return(true)
    loader = ActiveRestClient::LazyLoader.new(request)
    expect(loader.valid).to be_truthy
  end

end
