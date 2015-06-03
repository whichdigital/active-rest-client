require 'rspec'
require 'simplecov'
require 'active_rest_client'
require "ostruct"
require 'webmock/rspec'

if ENV["JENKINS"]
  require 'simplecov-rcov'
  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
elsif ENV["TRAVIS"]
  require 'coveralls'
  Coveralls.wear!
end

RSpec.configure do |config|
  config.color = true
  # config.formatter     = 'documentation'

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.mock_with :rspec do |mocks|
    # In RSpec 3, `any_instance` implementation blocks will be yielded the receiving
    # instance as the first block argument to allow the implementation block to use
    # the state of the receiver.
    # In RSpec 2.99, to maintain compatibility with RSpec 3 you need to either set
    # this config option to `false` OR set this to `true` and update your
    # `any_instance` implementation blocks to account for the first block argument
    # being the receiving instance.
    mocks.yield_receiver_to_any_instance_implementation_blocks = true
  end
end

class TestCacheStore
  def initialize
    @items = {}
  end

  def read(key)
    @items[key]
  end

  def write(key, value, options={})
    @items[key] = value
  end

  def fetch(key, &block)
    read(key) || begin
      value = block.call
      write(value)
      value
    end
  end
end

class FaradayResponseMock < ::ActiveRestClient::FaradayResponseProxy
  # The FaradayResponseMock is setup to automatically resolve all calls by default.
  # By setting auto_resolve to false it allows the spec to control when the response
  # is resolved, which simulates what it is like when inside a Faraday in_parallel block.
  def initialize(response, auto_resolve=true)
    super(response)
    @auto_resolve = auto_resolve
    @finished = false
  end

  def on_complete
    if @auto_resolve
      @finished = true
      yield(@response)
    else
      @callback = Proc.new
    end
  end

  # This is exactly what is called on responses after a Faraday in_parallel block ends.
  # This method simulates the end of in_parallel block.
  def finish
    @finished = true
    @callback.call(@response)
  end

  def finished?
    @finished
  end
end
