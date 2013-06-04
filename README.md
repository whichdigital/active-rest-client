# ActiveRestClient

This gem is for accessing REST services in an ActiveRecord style.  ActiveResource already exists for this, but it doesn't work where the resource naming doesn't follow Rails conventions, it doesn't have in-built caching and it's not as flexible in general.

## Installation

Add this line to your application's Gemfile:

    gem 'active_rest_client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_rest_client

## Usage

First you need to create your new model class:

```
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

Then you can use it like this:

```
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

Note, you can assign to any attribute, whether it exists or not before and read from any attribute (which will return nil if not found).

You can also call any mapped method as an instance variable which will pass the current attribute set in as parameters (either GET or POST depending on the mapped method type).  If the method returns a single instance it will assign the attributes of the calling object and return itself.  If the method returns a list of instances, it will only return the list. So, we could rewrite the create call above as:

```
@person = Person.new
@person.first_name = "John"
@person.last_name  = "Smith"
@person.create
puts @person.id
```

If the call would return a list of instances that are another object, you can also specify this when mapping the method using the `:has_many` option.  It doesn't call anything on that object except for instantiate it, but it does let you have

```
class Expense < ActiveRestClient::Base
  def inc_vat
    ex_vat * 1.20
  end
end

class Person < ActiveRestClient::Base
  get :find, "/people/:id"
  get :expenses, "/people/:id/expenses", has_many:Expense
end

@person = Person.find(1)
puts @person.expenses.reduce {|e| e.inc_vat}
```

The response of the #create call set the attributes at that point (any manually set attributes before that point are removed).

## Advanced Features

### Caching

You can enable Expires and ETag based caching with a simple line in the application.rb/production.rb:

```
ActiveRestClient::Base.perform_caching = true
```

or you can enable it per classes with:

```
class Person < ActiveRestClient::Base
  perform_caching true
end
```

If Rails is defined, it will default to using Rails.cache as the cache store, if not, you'll need to configure one with a `ActiveSupport::Cache::Store` compatible object using:

```
ActiveRestClient::Base.cache_store = Redis::Store.new("redis://localhost:6379/0/cache")
```

### Using filters

You can use filters to alter get/post parameters or the URL before a request.  This can either be a block or a named method (like ActionController's `before_filter`/`before_action` methods).

The filter is passed the name of the method (e.g. `:save`) and a request object. The request object has three public attributes `post_params` (a Hash of the POST parameters), `get_params` (a Hash of the GET parameters) and `url` (a String containing the full URL without GET parameters appended)

```
require 'secure_random'

class Person < ActiveRestClient::Base
  before_request do |name, request|
    if request.post? || name == :save
      id = request.post_params.delete(:id)
      request.get_params[:id] = id
    end
  end

  before_request :replace_token_in_url

  private

  def replace_token_in_url(name, request)
    request.url.gsub!("#token", SecureRandom.hex)
  end
end
```

### Authentication

You can authenticate with Basic authentication by putting the username and password in to the `base_url` or by setting them within the specific model:

```
class Person < ActiveRestClient::Base
  username 'api'
  password 'eb693ec-8252c-d6301-02fd0-d0fb7-c3485'

  # ...
end
```

### Faking Calls

There are times when an API hasn't been developed yet, so you want to fake the API call response.  To do this, simply pass a `fake` option when mapping the call containing the response.

```
class Person < ActiveRestClient::Base
  get :all, '/people', :fake => "[{first_name:"Johnny"}, {first_name:"Bob"}]"
end
```

### HTTP/Parse Error Handling

Sometimes the backend server may respond with a non-200/304 header, in which case the code will raise an `ActiveRestClient::HTTPClientException` for 4xx errors or an `ActiveRestClient::HTTPServerException` for 5xx errors.  These both have a `status` accessor and a `result` accessor (for getting access to the parsed body):

```
begin
  Person.all
rescue ActiveRestClient::HTTPClientException, ActiveRestClient::HTTPServerException => e
  Rails.logger.error("API returned #{e.status} : #{e.result.message}")
end
```

If the response is unparsable (e.g. not in the desired content type), then it will raise an `ActiveRestClient::ResponseParseException` which has a `status` accessor for the HTTP status code and a `body` accessor for the unparsed response body.

### Validation

You can create validations on your objects just like Rails' built in ActiveModel validations.  For example:

```
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

### Content Types

The default configuration is that the response should be JSON.  This automatically adds an "Accept" header "application/json".  If you prefer you can have the response as XML by using the following:

```
class Person < ActiveRestClient::Base
  content_type :xml

  # ...
end
```

This works for any MIME type registered in Rails using `Mime::Type.register`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
