require 'spec_helper'

describe "ActiveRestClient::Validation" do
  class SimpleValidationExample < OpenStruct
    include ActiveRestClient::Validation
    validates :first_name, presence:true
    validates :password, length:{within:6..12}
    validates :post_code, length:{minimum:6, maximum:8}
    validates :salary, numericality:true, minimum:20_000, maximum:50_000
  end

  it "should be able to register a validation" do
    expect(SimpleValidationExample._validations.size).to eq(4)
  end

  it "should be invalid if a required value isn't present" do
    a = SimpleValidationExample.new
    a.first_name = nil
    a.valid?
    expect(a._errors[:first_name].size).to eq(1)
  end

  it "should be valid if a required value is present" do
    a = SimpleValidationExample.new
    a.first_name = "John"
    a.valid?
    expect(a._errors[:first_name]).to be_empty
  end

  it "should be invalid if a length within value is outside the range" do
    a = SimpleValidationExample.new(password:"12345")
    a.valid?
    expect(a._errors[:password].size).to eq(1)
  end

  it "should be valid if a length within value is inside the range" do
    a = SimpleValidationExample.new(password:"123456")
    a.valid?
    expect(a._errors[:password].size).to eq(0)
  end

  it "should be invalid if a length is below the minimum" do
    a = SimpleValidationExample.new(post_code:"12345")
    a.valid?
    expect(a._errors[:post_code].size).to eq(1)
  end

  it "should be valid if a length is above or equal to the minimum and below the maximum" do
    a = SimpleValidationExample.new(post_code:"123456")
    a.valid?
    expect(a._errors[:post_code].size).to eq(0)
  end

  it "should be invalid if a length is above the maximum" do
    a = SimpleValidationExample.new(post_code:"123456789")
    a.valid?
    expect(a._errors[:post_code].size).to eq(1)
  end

  it "should be able to validate that a field is numeric" do
    a = SimpleValidationExample.new(salary:"Bob")
    a.valid?
    expect(a._errors[:salary].size).to be > 0
  end

  it "should be able to validate that a numeric field is above or equal to a minimum" do
    a = SimpleValidationExample.new(salary:10_000)
    a.valid?
    expect(a._errors[:salary].size).to be > 0
  end

  it "should be able to validate that a numeric field is above or equal to a minimum" do
    a = SimpleValidationExample.new(salary:100_000)
    a.valid?
    expect(a._errors[:salary].size).to be > 0
  end

  it "should be invalid when a block adds an error" do
    class ValidationExample1 < OpenStruct
      include ActiveRestClient::Validation
      validates :first_name do |object, name, value|
        object._errors[name] << "must be over 4 chars long" if value.length <= 4
      end
    end
    a = ValidationExample1.new(first_name:"John")
    a.valid?
    expect(a._errors[:first_name].size).to eq(1)
  end

  it "should be valid when a block doesn't add an error" do
    class ValidationExample2 < OpenStruct
      include ActiveRestClient::Validation
      validates :first_name do |object, name, value|
        object._errors[name] << "must be over 4 chars long" if value.length <= 4
      end
    end
    a = ValidationExample2.new(first_name:"Johnny")
    a.valid?
    expect(a._errors[:first_name]).to be_empty
  end

  it "should call valid? before making a request" do
    class ValidationExample3 < ActiveRestClient::Base
      whiny_missing true
      post :create, '/'
      validates :name, presence:true
    end

    expect_any_instance_of(ValidationExample3).to receive(:valid?)
    object = ValidationExample3.new
    expect { object.create }.to raise_exception(ActiveRestClient::ValidationFailedException)
  end
end
