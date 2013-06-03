require 'spec_helper'

describe ActiveRestClient::Attribute do
  it "should create a dirty attribute by default" do
    a = ActiveRestClient::Attribute.new("Hello world")
    expect(a).to be_dirty
  end

  it "should allow creation of a clean attribute" do
    a = ActiveRestClient::Attribute.new("Hello world", false)
    expect(a).to_not be_dirty
  end

  it "should allow an attribute to be clean after setting" do
    a = ActiveRestClient::Attribute.new("Hello world")
    a.clean!
    expect(a).to_not be_dirty
  end
end
