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
  config.color_enabled = true
  # config.formatter     = 'documentation'

  config.treat_symbols_as_metadata_keys_with_true_values = true

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
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
