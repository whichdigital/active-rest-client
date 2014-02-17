# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_rest_client/version'

Gem::Specification.new do |spec|
  spec.name          = "active_rest_client"
  spec.version       = ActiveRestClient::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Which Ltd", "Andy Jeffries"]
  spec.email         = ["swlicensing@which.co.uk", "andy@andyjeffries.co.uk"]
  spec.description   = %q{Accessing REST services in an ActiveRecord style}
  spec.summary       = %q{This gem is for accessing REST services in an ActiveRecord style.  ActiveResource already exists for this, but it doesn't work where the resource naming doesn't follow Rails conventions, it doesn't have in-built caching and it's not as flexible in general.}
  spec.homepage      = "http://whichdigital.github.io/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rspec_junit_formatter"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-rcov"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency 'terminal-notifier-guard'
  spec.add_development_dependency 'coveralls'

  spec.add_runtime_dependency "oj", "=2.1.4" # 2.1.7 breaks under linux
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "faraday"
  spec.add_runtime_dependency "patron", ">= 0.4.9" # 0.4.18 breaks against Curl v0.7.15 but works with webmock
end
