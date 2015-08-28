require 'spec_helper'

class XmlResponseExample < ActiveRestClient::Base
  base_url "http://www.example.com/v1/"
  get :root, "/root", ignore_xml_root: "feed", fake_content_type: "application/xml", fake: %Q{
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Example Feed</title>
    </feed>
  }
  get :atom, "/atom", fake: %Q{
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">

      <title>Example Feed</title>
      <link href="http://example.org/"/>
      <updated>2003-12-13T18:30:02Z</updated>
      <author>
        <name>John Doe</name>
      </author>
      <id>urn:uuid:60a76c80-d399-11d9-b93C-0003939e0af6</id>

      <entry>
        <title>Atom-Powered Robots Run Amok</title>
        <link href="http://example.org/2003/12/13/atom03"/>
        <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6a</id>
        <updated>2003-12-13T18:30:02Z</updated>
        <summary>Some text.</summary>
      </entry>

      <entry>
        <title>Something else cool happened</title>
        <link href="http://example.org/2015/08/11/andyjeffries"/>
        <id>urn:uuid:1225c695-cfb8-4ebb-aaaa-80da344efa6b</id>
        <updated>2015-08-11T18:30:02Z</updated>
        <summary>Some other text.</summary>
      </entry>

    </feed>}.strip_heredoc, fake_content_type: "application/xml"
end

describe XmlResponseExample do
  it "should parse the response without error" do
    expect {
      XmlResponseExample.atom
    }.to_not raise_error
  end

  it "provides the feed title" do
    @atom = XmlResponseExample.atom
    expect(@atom.feed.title).to eq("Example Feed")
  end

  it "provides the link's href" do
    @atom = XmlResponseExample.atom
    expect(@atom.feed.link.href).to eq("http://example.org/")
  end

  it "each entry item has a title" do
    @atom = XmlResponseExample.atom
    expect(@atom.feed.entry.class).to eq(ActiveRestClient::ResultIterator)
  end

  it "provides a list of entry items" do
    @atom = XmlResponseExample.atom
    expect(@atom.feed.entry[0].title).to eq("Atom-Powered Robots Run Amok")
    expect(@atom.feed.entry[1].title).to eq("Something else cool happened")
  end

  it "allows ignoring of the XML root node" do
    @feed = XmlResponseExample.root
    expect(@feed.title).to eq("Example Feed")
  end
end
