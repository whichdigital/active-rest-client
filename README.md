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

  get :all => "/people"
  get :find => "/people/:id"
  put :save => "/people/:id"
  post :create => "/people"
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

Note, you can assign to any attribute, whether it exists or not before and read from any attribute (which will return nil if not found).  You can also call any mapped method as an instance variable which will pass the current attribute set in as parameters (either GET or POST depending on the mapped method type).  So, we could rewrite the create call above as:

```
@person = Person.new
@person.first_name = "John"
@person.last_name  = "Smith"
@person.create
puts @person.id
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

### Validation



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
