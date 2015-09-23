# ActiveRestClient

[![Build Status](https://travis-ci.org/whichdigital/active-rest-client.svg?branch=master)](https://travis-ci.org/whichdigital/active-rest-client)
[![Coverage Status](https://coveralls.io/repos/whichdigital/active-rest-client/badge.png)](https://coveralls.io/r/whichdigital/active-rest-client)
[![Code Climate](https://codeclimate.com/github/whichdigital/active-rest-client.png)](https://codeclimate.com/github/whichdigital/active-rest-client)
[![Gem Version](https://badge.fury.io/rb/active_rest_client.png)](http://badge.fury.io/rb/active_rest_client)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/whichdigital/active-rest-client.svg)](http://isitmaintained.com/project/whichdigital/active-rest-client "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/whichdigital/active-rest-client.svg)](http://isitmaintained.com/project/whichdigital/active-rest-client "Percentage of issues still open")

This gem is for accessing REST services in an ActiveRecord style.  ActiveResource already exists for this, but it doesn't work where the resource naming doesn't follow Rails conventions, it doesn't have in-built caching and it's not as flexible in general.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_rest_client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_rest_client

## Usage

First you need to create your new model class:

```ruby
# config/environments/production.rb
MyApp::Application.configure do
  # ...
  config.api_server_url = "https://www.example.com/api/v1"
end

# app/models/person.rb
class Person < ActiveRestClient::Base
  base_url Rails.application.config.api_server_url

  get :all, "/people"
  get :find, "/people/:id"
  put :save, "/people/:id"
  post :create, "/people"
end
```

Note I've specified the base_url in the class above.  This is useful where you want to be explicit or use different APIs for some classes and be explicit. If you have one server that's generally used, you can set it once with a simple line in a `config/initializer/{something}.rb` file:

```ruby
ActiveRestClient::Base.base_url = "https://www.example.com/api/v1"
```

Any `base_url` settings in specific classes override this declared default. You can then use your new class like this:

```ruby
# Create a new person
@person = Person.create(
  first_name:"John"
  last_name:"Smith"
)

# Find a person (not needed after creating)
id = @person.id
@person = Person.find(id)

# Update a person
@person.last_name = "Jones"
@person.save

# Get all people
@people = Person.all
@people.each do |person|
  puts "Hi " + person.first_name
end
```

If an API returns an array of results and you have [will_paginate](https://rubygems.org/gems/will_paginate) installed then you can call the paginate method to return a particular page of the results (note: this doesn't reduce the load on the server, but it can help with pagination if you have a cached response).

```ruby
@people = Person.all
@people.paginate(page: 1, per_page: 10).each do |person|
  puts "You made the first page: " + person.first_name
end
```

Note, you can assign to any attribute, whether it exists or not before and read from any attribute (which will return nil if not found).  If you pass a string or a number to a method it will assume that it's for the "id" field.  Any other field values must be passed as a hash and you can't mix passing a string/number and a hash.

```ruby
@person = Person.find(1234)  # valid
@person = Person.find("1234")  # valid
@person = Person.find(:id => 1234)  # valid
@person = Person.find(:id => 1234, :name => "Billy")  # valid
@person = Person.find(1234, :name => "Billy")  # invalid
```

You can also call any mapped method as an instance variable which will pass the current attribute set in as parameters (either GET or POST depending on the mapped method type).  If the method returns a single instance it will assign the attributes of the calling object and return itself.  If the method returns a list of instances, it will only return the list. So, we could rewrite the create call above as:

```ruby
@person = Person.new
@person.first_name = "John"
@person.last_name  = "Smith"
@person.create
puts @person.id
```

The response of the #create call set the attributes at that point (any manually set attributes before that point are removed).

If you have attributes beginning with a number, Ruby doesn't like this.  So, you can use hash style notation to read/write the attributes:

```ruby
@tv = Tv.find(model:"UE55U8000") # { "properties" : {"3d" : false} }
puts @tv.properties["3d"]
@tv.properties["3d"] = true
```

If you want to debug the response, using inspect on the response object may well be useful.  However, if you want a simpler output, then you can call `#to_json` on the response object:

```ruby
@person = Person.find(email:"something@example.com")
puts @person.to_json
```

## Advanced Features

### Faraday Configuration

ActiveRestClient uses Faraday to allow switching HTTP backends, the default is to just use Faraday's default. To change the used backend just set it in the class by setting `adapter` to a Faraday supported adapter symbol.

```ruby
ActiveRestClient::Base.adapter = :net_http
# or ...
ActiveRestClient::Base.adapter = :patron
```

In versions before 1.2.0 the adapter was hardcoded to `:patron`, so if you want to ensure it still uses Patron, you should set this setting.

If you want more control you can pass a **complete** configuration block ("complete" means that the block does not *override* [the default configuration](https://github.com/whichdigital/active-rest-client/blob/5b1953d89e26c02ca74f74464ccb7cd4c9439dcc/lib/active_rest_client/configuration.rb#L184-L201), but rather *replaces* it). For available config variables look into the Faraday documentation.

```ruby
ActiveRestClient::Base.faraday_config do |faraday|
  faraday.adapter(:net_http)
  faraday.options.timeout       = 10
  faraday.headers['User-Agent'] = "ActiveRestClient/#{ActiveRestClient::VERSION}"
end
```
### Associations

There are two types of association.  One assumes when you call a method you actually want it to call the method on a separate class (as that class has other methods that are useful).  The other is lazy loading related classes from a separate URL.

#### Association Type 1 - Loading Other Classes

If the call would return a single instance or a list of instances that should be considered another object, you can also specify this when mapping the method using the `:has_one` or `:has_many` options respectively.  It doesn't call anything on that object except for instantiate it, but it does let you have objects of a different class to the one you initially called.

```ruby
class Expense < ActiveRestClient::Base
  def inc_vat
    ex_vat * 1.20
  end
end

class Address < ActiveRestClient::Base
  def full_string
    return "#{self.street}, #{self.city}, #{self.region}, #{self.country}"
  end
end

class Person < ActiveRestClient::Base
  get :find, "/people/:id", :has_many => {:expenses => Expense}, :has_one => {:address => Address}
end

@person = Person.find(1)
puts @person.expenses.reduce {|e| e.inc_vat}
puts @person.address.full_string
```

#### Association Type 2 - Lazy Loading From Other URLs

When mapping the method, passing a list of attributes will cause any requests for those attributes to mapped to the URLs given in their responses.  The response for the attribute may be one of the following:

```ruby
"attribute" : "URL"
"attribute" : ["URL", "URL"]
"attribute" : { "url" : "URL"}
"attribute" : { "href" : "URL"}
"attribute" : { "something" : "URL"}
```

The difference between the last 3 examples is that a key of `url` or `href` signifies it's a single object that is lazy loaded from the value specified.  Any other keys assume that it's a nested set of URLs (like in the array situation, but accessible via the keys - e.g. object.attribute.something in the above example).

It is required that the URL is a complete URL including a protocol starting with "http".  To configure this use code like:

```ruby
class Person < ActiveRestClient::Base
  get :find, "/people/:id", :lazy => [:orders, :refunds]
end
```

And use it like this:

```ruby
# Makes a call to /people/1
@person = Person.find(1)

# Makes a call to the first URL found in the "books":[...] array in the article response
# only makes the HTTP request when first used though
@person.books.first.name
```

#### Association Type 3 - HAL Auto-loaded Resources

You don't need to define lazy attributes if they are defined using [HAL](http://stateless.co/hal_specification.html) (with an optional embedded representation).  If your resource has an `_links` item (and optionally an `_embedded` item) then it will automatically treat the linked resources (with the `_embedded` cache) as if they were defined using `:lazy` as per type 2 above.

If you need to, you can access properties of the HAL association.  By default just using the HAL association gets the embedded resource (or requests the remote resource if not available in the `_embedded` list).

```ruby
@person = Person.find(1)
@person.students[0]._hal_attributes("title")
```

#### Association Type 4 - Nested Resources

It's common to have resources that are logically children of other resources. For example, suppose that your API includes these endpoints:

| HTTP Verb | Path                        |                                          |
|-----------|-----------------------------|------------------------------------------|
| POST      | /magazines/:magazine_id/ads | create a new ad belonging to a magazine  |
| GET       | /magazines/:magazine_id/ads | display a list of all ads for a magazine |

In these cases, your child class will contain the following:

```ruby
class Ad < ActiveRestClient::Base
  post :create, "/magazines/:magazine_id/ads"
  get :all, "/magazines/:magazine_id/ads"
end
```

You can then access Ads by specifying their magazine IDs:

```ruby
Add.all(magazine_id: 1)
Add.create(magazine_id: 1, title: "My Add Title")
```

#### Combined Example

OK, so let's say you have an API for getting articles.  Each article has a property called `title` (which is a string) and a property `images` which includes a list of URIs.  Following this URI would take you to a image API that returns the image's `filename` and `filesize`.  We'll also assume this is a HAL compliant API. We would declare our two models (one for articles and one for images) like the following:

```ruby
class Article < ActiveRestClient::Base
  get :find, '/articles/:id', has_many:{:images => Image} # ,lazy:[:images] isn't needed as we're using HAL
end

class Image < ActiveRestClient::Base
  # You may have mappings here

  def nice_size
    "#{size/1024}KB"
  end
end
```

We assume the /articles/:id call returns something like the following:

```json
{
  "title": "Fly Fishing",
  "author": "J R Hartley",
  "images": [
    "http://api.example.com/images/1",
    "http://api.example.com/images/2"
  ]
}
```

We said above that the /images/:id call would return something like:

```json
{
  "filename": "http://cdn.example.com/images/foo.jpg",
  "filesize": 123456
}
```

When it comes time to use it, you would do something like this:

```ruby
@article = Article.find(1)
@article.images.is_a?(ActiveRestClient::LazyAssociationLoader)
@article.images.size == 2
@article.images.each do |image|
  puts image.inspect
end
```

At this point, only the HTTP call to '/articles/1' has been made.  When you actually start using properties of the images list/image object then it makes a call to the URL given in the images list and you can use the properties as if it was a nested JSON object in the original response instead of just a URL:

```ruby
@image = @article.images.first
puts @image.filename
# => http://cdn.example.com/images/foo.jpg
puts @image.filesize
# => 123456
```

You can also treat `@image` looks like an Image class (and you should 100% treat it as one) it's technically a lazy loading proxy.  So, if you cache the views for your application should only make HTTP API requests when actually necessary.

```ruby
puts @image.nice_size
# => 121KB
```

### Caching

Expires and ETag based caching is enabled by default, but with a simple line in the application.rb/production.rb you can disable it:

```ruby
ActiveRestClient::Base.perform_caching = false
```

or you can disable it per classes with:

```ruby
class Person < ActiveRestClient::Base
  perform_caching false
end
```

If Rails is defined, it will default to using Rails.cache as the cache store, if not, you'll need to configure one with a `ActiveSupport::Cache::Store` compatible object using:

```ruby
ActiveRestClient::Base.cache_store = Redis::Store.new("redis://localhost:6379/0/cache")
```

### Using filters

You can use filters to alter get/post parameters, the URL or set the post body (doing so overrides normal parameter insertion in to the body) before a request or to adjust the response after a request.  This can either be a block or a named method (like ActionController's `before_filter`/`before_action` methods).

The filter is passed the name of the method (e.g. `:save`) and an object (a request object for `before_request` and a response object for `after_request`). The request object has four public attributes `post_params` (a Hash of the POST parameters), `get_params` (a Hash of the GET parameters), headers and `url` (a String containing the full URL without GET parameters appended)

```ruby
require 'secure_random'

class Person < ActiveRestClient::Base
  before_request do |name, request|
    if request.post? || name == :save
      id = request.post_params.delete(:id)
      request.get_params[:id] = id
    end
  end

  before_request :replace_token_in_url

  before_request :add_authentication_details

  before_request :replace_body

  before_request :override_default_content_type

  private

  def replace_token_in_url(name, request)
    request.url.gsub!("#token", SecureRandom.hex)
  end

  def add_authentication_details(name, request)
    request.headers["X-Custom-Authentication-Token"] = ENV["AUTH_TOKEN"]
  end

  def replace_body(name, request)
    if name == :create
      request.body = request.post_params.to_json
    end
  end

  def override_default_content_type(name, request)
    if name == :save
      request.headers["Content-Type"] = "application/json"
    end
  end
end
```

If you need to, you can create a custom parent class with a `before_request` filter and all children will inherit this filter.

```ruby
class MyProject::Base < ActiveRestClient::Base
  before_request do |name, request|
    request.get_params[:api_key] = "1234567890-1234567890"
  end
end

class Person < MyProject::Base
  # No need to declare a before_request for :api_key, already defined by the parent
end
```

After filters work in exactly the same way:

```ruby
class Person < ActiveRestClient::Base
  after_request :fix_empty_content

  private

  def fix_empty_content(name, response)
    if response.status == 204 && response.body.blank?
      response.body = '{"empty": true}'
    end
  end
end
```

### Lazy Loading

ActiveRestClient supports lazy loading (delaying the actual API call until the response is actually used, so that views can be cached without still causing API calls).

**Note: Currently this isn't enabled by default, but this is likely to change in the future to make lazy loading the default.**

To enable it, simply call the lazy_load! method in your class definition:

```ruby
class Article < ActiveRestClient::Base
  lazy_load!
end
```

If you have a ResultIterator that has multiple objects, each being lazy loaded or HAL linked resources that isn't loaded until it's used, you can actually parallelise the fetching of the items using code like this:

```ruby
items.parallelise(:id)

# or

items.parallelise do |item|
  item.id
end
```

This will return an array of the named method for each object or the response from the block and will have loaded the objects in to the resource.


### Authentication

#### Basic

You can authenticate with Basic authentication by putting the username and password in to the `base_url` or by setting them within the specific model:

```ruby
class Person < ActiveRestClient::Base
  username 'api'
  password 'eb693ec-8252c-d6301-02fd0-d0fb7-c3485'

  # ...
end
```

#### Api-Auth

Using the [Api-Auth](https://github.com/mgomes/api_auth) integration it is very easy to sign requests. Include the Api-Auth gem in your Gemfile and in then add it to your application. Then simply configure Api-Auth one time in your app and all requests will be signed from then on.

```ruby
require 'api-auth'

@access_id = '123456'
@secret_key = 'abcdef'
ActiveRestClient::Base.api_auth_credentials(@access_id, @secret_key)
```

You can also specify different credentials for different models just like configuring base_url
```ruby
class Person < ActiveRestClient::Base
  api_auth_credentials('123456', 'abcdef')
end
```

For more information on how to generate an access id and secret key please read the [Api-Auth](https://github.com/mgomes/api_auth) documentation.

### Body Types

By default ActiveRestClient puts the body in to normal CGI parameters in K=V&K2=V2 format.  However, if you want to use JSON for your PUT/POST requests, you can use either (the other option, the default, is `:form_encoded`):

```ruby
class Person < ActiveRestClient::Base
  request_body_type :json
  # ...
end
```

or

```ruby
ActiveRestClient::Base.request_body_type = :json
```

This will also set the header `Content-Type` to `application/x-www-form-urlencoded` by default or `application/json; charset=utf-8` when `:json`. You can override this using the filter `before_request`.

If you have an API that is inconsistent in its body type requirements, you can also specify it on the individual method mapping:

```ruby
class Person < ActiveRestClient::Base
  request_body_type :form_encoded # This is the default, but just for demo purposes

  get :all, '/people', request_body_type: :json
end
```

### Parallel Requests

Sometimes you know you will need to make a bunch of requests and you don't want to wait for one to finish to start the next. When using parallel requests there is the potential to finish many requests all at the same time taking only as long as the single longest request. To use parallel requests you will need to set Active-Rest-Client to use a Faraday adapter that supports parallel requests [(such as Typhoeus)](https://github.com/lostisland/faraday/wiki/Parallel-requests).
```ruby
# Set adapter to Typhoeus to use parallel requests
ActiveRestClient::Base.adapter = :typhoeus
```

Now you just need to get ahold of the connection that is going to make the requests by specifying the same host that the models will be using. When inside the `in_parallel` block call request methods as usual and access the results after the `in_parallel` block ends.
```ruby
ActiveRestClient::ConnectionManager.in_parallel('https://www.example.com') do
    @person = Person.find(1234)
    @employers = Employer.all

    puts @person #=> nil
    puts @employers #=> nil
end # The requests are all fired in parallel during this end statement

puts @person.name #=> "John"
puts @employers.size #=> 7
```

### Faking Calls

There are times when an API hasn't been developed yet, so you want to fake the API call response.  To do this, you can simply pass a `fake` option when mapping the call containing the response.

```ruby
class Person < ActiveRestClient::Base
  get :all, '/people', fake: [{first_name:"Johnny"}, {first_name:"Bob"}]
end
```

You may want to run a proc when faking data (to put information from the parameters in to the response or return different responses depending on the parameters).  To do this just pass a proc to :fake:

```ruby
class Person < ActiveRestClient::Base
  get :all, '/people', fake: ->(request) { {result: request.get_params[:id]} }
end
```

### Raw Requests

Sometimes you have have a URL that you just want to force through, but have the response handled in the same way as normal objects or you want to have the filters run (say for authentication).  The easiest way to do that is to call `_request` on the class:

```ruby
class Person < ActiveRestClient::Base
end

people = Person._request('http://api.example.com/v1/people') # Defaults to get with no parameters
# people is a normal ActiveRestClient object, implementing iteration, HAL loading, etc.

Person._request('http://api.example.com/v1/people', :post, {id:1234,name:"John"}) # Post with parameters
```

If you want to use a lazy loaded request instead (so it will create an object that will only call the API if you use it), you can use `_lazy_request` instead of `_request`.  If you want you can create a construct that creates and object that lazy loads itself from a given method (rather than a URL):

```ruby
@person = Person._lazy_request(Person._request_for(:find, 1234))
```

This initially creates an ActiveRestClient::Request object as if you'd called `Person.find(1234)` which is then passed in to the `_lazy_request` method to return an object that will call the request if any properties are actually used.  This may be useful at some point, but it's actually easier to just prefix the `find` method call with `lazy_` like:

```ruby
@person = Person.lazy_find(1234)
```

Doing this will try to find a literally mapped method called "lazy_find" and if it fails, it will try to use "find" but instantiate the object lazily.

### Plain Requests

If you are already using ActiveRestClient but then want to simply call a normal URL and receive the resulting content as a string (i.e. not going through JSON parsing or instantiating in to an ActiveRestClient::Base descendent) you can use code like this:

```ruby
class Person < ActiveRestClient::Base
end

people = Person._plain_request('http://api.example.com/v1/people') # Defaults to get with no parameters
# people is a normal ActiveRestClient object, implementing iteration, HAL loading, etc.

Person._plain_request('http://api.example.com/v1/people', :post, {id:1234,name:"John"}) # Post with parameters
```

The parameters are the same as for `_request`, but it does no parsing on the response

### Proxying APIs

Sometimes you may be working with an old API that returns JSON in a less than ideal format or the URL or parameters required have changed.  In this case you can define a descendent of `ActiveRestClient::ProxyBase`, pass it to your model as the proxy and have it rework URLs/parameters on the way out and the response on the way back in (already converted to a Ruby hash/array). By default any non-proxied URLs are just passed through to the underlying connection layer. For example:

```ruby
class ArticleProxy < ActiveRestClient::ProxyBase
  get "/all" do
    url "/all_people" # Equiv to url.gsub!("/all", "/all_people") if you wanted to keep params
    response = passthrough
    translate(response) do |body|
      body["first_name"] = body.delete("fname")
      body
    end
  end
end

class Article < ActiveRestClient::Base
  proxy ArticleProxy
  base_url "http://www.example.com"

  get :all, "/all", fake:"{\"name\":\"Billy\"}"
  get :list, "/list", fake:"[{\"name\":\"Billy\"}, {\"name\":\"John\"}]"
end

Article.all.first_name == "Billy"
```

This example does two things:

1. It rewrites the incoming URL for any requests matching "*/all*" to "/all_people"
2. It uses the `translate` method to move the "fname" attribute from the response body to be called "first_name".  The translate method must return the new object at the end (either the existing object alterered, or a new object to replace it with)

As the comment shows, you can use `url value` to set the request URL to a particular value, or you can call `gsub!` on the url to replace parts of it using more complicated regular expressions.

You can use the `get_params` or `post_params` methods within your proxy block to amend/create/delete items from those request parameters, like this:

```ruby
get "/list" do
  get_params["id"] = get_params.delete("identifier")
  passthrough
end
```

This example renames the get_parameter for the request from `identifier` to `id` (the same would have worked with post_params if it was a POST/PUT request).  The `passthrough` method will take care of automatically recombining them in to the URL or encoding them in to the body as appropriate.

If you want to manually set the body for the API yourself you can use the `body` method

```ruby
put "/update" do
  body "{\"id\":#{post_params["id"]}}"
  passthrough
end
```

This example takes the `post_params["id"]` and converts the body from being a normal form-encoded body in to being a JSON body.

The proxy block expects one of three things to be the return value of the block.

1. The first options is that the call to `passthrough` is the last thing and it calls down to the connection layer and returns the actual response from the server in to the "API->Object" mapping layer ready for use in your application
2. The second option is to save the response from `passthrough` and use `translate` on it to alter the structure.
3. The third option is to use `render` if you want to completely fake an API and return the JSON yourself

To completely fake the API, you can do the following.  Note, this is also achievable using the `fake` setting when mapping a method, however by doing it in a Proxy block means you can dynamically generate the JSON rather than just a hard coded string.

```ruby
put "/fake" do
  render "{\"id\":1234}"
end
```

### Translating APIs

**IMPORTANT: This functionality has been deprecated in favour of the "Proxying APIs" functionality above.  You should aim to remove this from your code as soon as possible.**

Sometimes you may be working with an API that returns JSON in a less than ideal format.  In this case you can define a barebones class and pass it to your model.  The Translator class must have class methods that are passed the JSON object and should return an object in the correct format.  It doesn't need to have a method unless it's going to translate that mapping though (so in the example below there's no list method). For example:

```ruby
class ArticleTranslator
  def self.all(object)
    ret = {}
    ret["first_name"] = object["name"]
    ret
  end
end

class Article < ActiveRestClient::Base
  translator ArticleTranslator
  base_url "http://www.example.com"

  get :all, "/all", fake:"{\"name\":\"Billy\"}"
  get :list, "/list", fake:"[{\"name\":\"Billy\"}, {\"name\":\"John\"}]"
end

Article.all.first_name == "Billy"
```

### Default Parameters

If you want to specify default parameters you shouldn't use a path like:

```ruby
class Person < ActiveRestClient::Base
  get :all, '/people?all=true' # THIS IS WRONG!!!
end
```

You should use a defaults option to specify the defaults, then they will be correctly overwritten when making the request

```ruby
class Person < ActiveRestClient::Base
  get :all, '/people', :defaults => {:active => true}
end

@people = Person.all(active:false)
```

### HTTP/Parse Error Handling

Sometimes the backend server may respond with a non-200/304 header, in which case the code will raise an `ActiveRestClient::HTTPClientException` for 4xx errors or an `ActiveRestClient::HTTPServerException` for 5xx errors.  These both have a `status` accessor and a `result` accessor (for getting access to the parsed body):

```ruby
begin
  Person.all
rescue ActiveRestClient::HTTPClientException, ActiveRestClient::HTTPServerException => e
  Rails.logger.error("API returned #{e.status} : #{e.result.message}")
end
```

If the response is unparsable (e.g. not in the desired content type), then it will raise an `ActiveRestClient::ResponseParseException` which has a `status` accessor for the HTTP status code and a `body` accessor for the unparsed response body.

### Validation

You can create validations on your objects just like Rails' built in ActiveModel validations.  For example:

```ruby
class Person < ActiveRestClient::Base
  validates :first_name, presence:true
  validates :password, length:{within:6..12}
  validates :post_code, length:{minimum:6, maximum:8}
  validates :salary, numericality:true, minimum:20_000, maximum:50_000

  validates :first_name do |object, name, value|
    object.errors[name] << "must be over 4 chars long" if value.length <= 4
  end

  get :index, '/'
end
```

Note the block based validation is responsible for adding errors to `object.errors[name]` (and this will automatically be ready for `<<` inserting into).

Validations are run when calling `valid?` or when calling any API on an instance (and then only if it is `valid?` will the API go on to be called).

### Debugging

You can turn on verbose debugging to see what is sent to the API server and what is returned in one of these two ways:

```ruby
class Article < ActiveRestClient::Base
  verbose true
end

class Person < ActiveRestClient::Base
  verbose!
end
```

By default verbose logging isn't enabled, so it's up to the developer to enable it (and remember to disable it afterwards).  It does use debug level logging, so it shouldn't fill up a correctly configured production server anyway.

If you prefer to record the output of an API call in a more automated fashion you can use a callback called `record_response` like this:

```ruby
class Article < ActiveRestClient::Base
  record_response do |url, response|
    File.open(url.parameterize, "w") do |f|
      f << response.body
    end
  end
end
```

## Beta Features

### XML Responses

ActiveRestClient uses Crack to allow parsing of XML responses.  For example, given an XML response of (with a content type of `application/xml` or `text/xml`):

```xml
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

</feed>
```

You can use:

```ruby
class Feed < ActiveRestClient::Base
  base_url "http://www.example.com/v1/"
  get :atom, "/atom"
end

@atom = Feed.atom

puts @atom.feed.title
puts @atom.feed.link.href
@atom.feed.entry.each do |entry|
  puts "#{entry.title} -> #{entry.link.href}"
end
```

If your XML object comes back with a root node and you'd like to ignore it, you can define the mapping as:

```ruby
class Feed < ActiveRestClient::Base
  get :atom, "/atom", ignore_xml_root: "feed"
end
```

For testing purposes, if you are using a `fake` content response when defining your endpoint, you should also provide `fake_content_type: "application/xml"` so that the parser knows to use XML parsing.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request