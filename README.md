# ActiveRestClient

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

Note I've specified the base_url in the class above.  This is usful where you want to be explicit or use different APIs for some classes and be explicit. If you have one server that's generally used, you can set it once with a simple line in the application.rb/production.rb:

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

## Advanced Features

### Associations

There are two types of association.  One assumes when you call a method you actually want it to call the method on a separate class (as that class has other methods that are useful).  The other is lazy loading related classes from a separate URL.

#### Association Type 1 - Loading Other Classes

If the call would return a list of instances that should be considered another object, you can also specify this when mapping the method using the `:has_many` option.  It doesn't call anything on that object except for instantiate it, but it does let you have objects of a different class to the one you initially called.

```ruby
class Expense < ActiveRestClient::Base
  def inc_vat
    ex_vat * 1.20
  end
end

class Person < ActiveRestClient::Base
  get :find, "/people/:id", :has_many => {:expenses => Expense}
end

@person = Person.find(1)
puts @person.expenses.reduce {|e| e.inc_vat}
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

You don't need to define lazy attributes if they are defined using [HAL](http://stateless.co/hal_specification.html) (with an optional embedded representation).  If your resource has an _links item (and optionally an _embedded item) then it will automatically treat the linked resources (with the _embedded cache) as if they were defined using `:lazy` as per type 2 above.

If you need to, you can access properties of the HAL association.  By default just using the HAL association gets the embedded resource (or requests the remote resource if not available in the _embedded list).

```ruby
@person = Person.find(1)
@person.students[0]._hal_attributes("title")
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

You can enable Expires and ETag based caching with a simple line in the application.rb/production.rb:

```ruby
ActiveRestClient::Base.perform_caching = true
```

or you can enable it per classes with:

```ruby
class Person < ActiveRestClient::Base
  perform_caching true
end
```

If Rails is defined, it will default to using Rails.cache as the cache store, if not, you'll need to configure one with a `ActiveSupport::Cache::Store` compatible object using:

```ruby
ActiveRestClient::Base.cache_store = Redis::Store.new("redis://localhost:6379/0/cache")
```

### Using filters

You can use filters to alter get/post parameters or the URL before a request.  This can either be a block or a named method (like ActionController's `before_filter`/`before_action` methods).

The filter is passed the name of the method (e.g. `:save`) and a request object. The request object has four public attributes `post_params` (a Hash of the POST parameters), `get_params` (a Hash of the GET parameters), headers and `url` (a String containing the full URL without GET parameters appended)

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

  private

  def replace_token_in_url(name, request)
    request.url.gsub!("#token", SecureRandom.hex)
  end

  def add_authentication_details(name, request)
    request.headers["X-Custom-Authentication-Token"] = ENV["AUTH_TOKEN"]
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

### Lazy Loading

ActiveRestClient supports lazy loading (delaying the actual API call until the response is actually used, so that views can be cached without still causing API calls).

**Note: Currently this isn't enabled by default, but this is likely to change in the future to make lazy loading the default.**

To enable it, simply call the lazy_load! method in your class definition:

```ruby
class Article < ActiveRestClient::Base
  lazy_load!
end
```

### Authentication

You can authenticate with Basic authentication by putting the username and password in to the `base_url` or by setting them within the specific model:

```ruby
class Person < ActiveRestClient::Base
  username 'api'
  password 'eb693ec-8252c-d6301-02fd0-d0fb7-c3485'

  # ...
end
```

### Faking Calls

There are times when an API hasn't been developed yet, so you want to fake the API call response.  To do this, simply pass a `fake` option when mapping the call containing the response.

```ruby
class Person < ActiveRestClient::Base
  get :all, '/people', :fake => "[{first_name:"Johnny"}, {first_name:"Bob"}]"
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

### Translating APIs

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

TranslatorClientExample.all.first_name == "Billy"
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
class Article
  verbose true
end

class Person
  verbose!
end
```

By default verbose logging isn't enabled, so it's up to the developer to enable it (and remember to disable it afterwards).  It does use debug level logging, so it shouldn't fill up a correctly configured production server anyway.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
