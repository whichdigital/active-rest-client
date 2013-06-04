require 'spec_helper'

describe "ActiveRestClient::Validation" do
  class SimpleValidationExample < OpenStruct
    include ActiveRestClient::Validation
    validates :first_name, presence:true
  end

  it "should be able to register a validation" do
    expect(SimpleValidationExample._validations.size).to eq(1)
  end

  it "should be invalid if a required value isn't present" do
    a = SimpleValidationExample.new
    a.first_name = nil
    a.valid?
    expect(a.errors[:first_name].size).to eq(1)
  end

  it "should be valid if a required value is present" do
    a = SimpleValidationExample.new
    a.first_name = "John"
    a.valid?
    expect(a.errors[:first_name]).to be_empty
  end

  it "should be invalid when a block adds an error" do
    class ValidationExample1 < OpenStruct
      include ActiveRestClient::Validation
      validates :first_name do |object, name, value|
        object.errors[name] << "must be over 4 chars long" if value.length <= 4
      end
    end
    a = ValidationExample1.new(first_name:"John")
    a.valid?
    expect(a.errors[:first_name].size).to eq(1)
  end

  it "should be valid when a block doesn't add an error" do
    class ValidationExample2 < OpenStruct
      include ActiveRestClient::Validation
      validates :first_name do |object, name, value|
        object.errors[name] << "must be over 4 chars long" if value.length <= 4
      end
    end
    a = ValidationExample2.new(first_name:"Johnny")
    a.valid?
    expect(a.errors[:first_name]).to be_empty
  end
end
