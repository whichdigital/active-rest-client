require 'faraday'

if defined?("Faraday::Env")
  class Faraday::Env
    alias_method :headers, :response_headers
  end
end
