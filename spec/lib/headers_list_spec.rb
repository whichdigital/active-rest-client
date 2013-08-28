require 'spec_helper'

describe ActiveRestClient::HeadersList do
  let(:headers_list) { ActiveRestClient::HeadersList.new }

  it "should remember stored headers" do
    url = "http://www.google.com"
    headers_list["X-My-Header"] = url
    expect(headers_list["X-My-Header"]).to eq(url)
  end

  it "should remember overwrite normal headers" do
    url = "http://www.google.com"
    headers_list["X-My-Header"] = "SHOULD NEVER BE SEEN"
    headers_list["X-My-Header"] = url
    expect(headers_list["X-My-Header"]).to eq(url)
  end

  it "should append to specific headers, such as Set-cookie" do
    headers_list["Set-Cookie"] = "first_value"
    headers_list["Set-Cookie"] = "second_value"
    expect(headers_list["Set-Cookie"]).to eq(%w{first_value second_value})
  end

  it "should not be case sensitive on header names when setting headers" do
    url = "http://www.google.com"
    headers_list["X-My-Header"] = "SHOULD NEVER BE SEEN"
    headers_list["X-MY-HEADER"] = url
    expect(headers_list["X-My-Header"]).to eq(url)
  end

  it "should not be case sensitive on header names when getting headers" do
    url = "http://www.google.com"
    headers_list["X-My-Header"] = url
    expect(headers_list["X-MY-HEADER"]).to eq(url)
  end

  it "should allow iterating over headers set, by default with array items returned whole" do
    headers_list["X-My-Header"] = "http://www.google.com"
    headers_list["Set-Cookie"] = "first_value"
    headers_list["SET-COOKIE"] = "second_value"
    values = []
    headers_list.each do |name, value|
      values << "#{name}=#{value.to_s}"
    end
    expect(values.size).to eq(2)
    expect(values).to eq(["X-My-Header=http://www.google.com", "Set-Cookie=[\"first_value\", \"second_value\"]"])
  end

  it "should allow iterating over headers set splitting array headers in to individual ones" do
    headers_list["X-My-Header"] = "http://www.google.com"
    headers_list["Set-Cookie"] = "first_value"
    headers_list["SET-COOKIE"] = "second_value"
    values = []
    headers_list.each(true) do |name, value|
      values << "#{name}=#{value.to_s}"
    end
    expect(values.size).to eq(3)
    expect(values).to eq(["X-My-Header=http://www.google.com", "Set-Cookie=first_value", "Set-Cookie=second_value"])
  end
end
