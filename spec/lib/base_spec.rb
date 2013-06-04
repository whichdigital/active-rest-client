require 'spec_helper'

class EmptyExample < ActiveRestClient::Base
  whiny_missing true
end

describe ActiveRestClient::Base do
  it 'should instantiate a new descendant' do
    expect{EmptyExample.new}.to_not raise_error(Exception)
  end

  it "should not instantiate a new base class" do
    expect{ActiveRestClient::Base.new}.to raise_error(Exception)
  end

  it "should save attributes passed in constructor" do
    client = EmptyExample.new(:test => "Something")
    expect(client._attributes[:test]).to be_a(String)
  end

  it "should allow attribute reading using missing method names" do
    client = EmptyExample.new(:test => "Something")
    expect(client.test).to eq("Something")
  end

  it "should store attributes set using missing method names and mark them as dirty" do
    client = EmptyExample.new()
    client.test = "Something"
    expect(client.test.to_s).to eq("Something")
    expect(client).to be_dirty
  end

  it "should overwrite attributes already set and mark them as dirty" do
    client = EmptyExample.new(:hello => "World")
    client._clean!
    expect(client).to_not be_dirty

    client.hello = "Everybody"
    expect(client).to be_dirty
  end

  it "should save the base URL for the API server" do
    class BaseExample < ActiveRestClient::Base
      base_url "https://ww.example.com/api/v1"
    end
    expect(BaseExample.base_url).to eq("https://ww.example.com/api/v1")
  end

  it "should include the Mapping module" do
    expect(EmptyExample).to respond_to(:_calls)
    expect(EmptyExample).to_not respond_to(:_non_existant)
  end

  it "should be able to easily clean all attributes" do
    client = EmptyExample.new(hello:"World", goodbye:"Everyone")
    expect(client).to be_dirty
    client._clean!
    expect(client).to_not be_dirty
  end

  it "should not overly pollute the instance method namespace to reduce chances of clashing (<5 instance methods)" do
    instance_methods = EmptyExample.instance_methods - Object.methods
    instance_methods = instance_methods - instance_methods.grep(/^_/)
    expect(instance_methods.size).to be < 5
  end

end
