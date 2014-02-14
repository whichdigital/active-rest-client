require 'faraday'

module ActiveRestClient

  class TimeoutException < StandardError ; end
  class ConnectionFailedException < StandardError ; end

  class Connection
    attr_accessor :session, :base_url

    def initialize(base_url)
      @base_url                      = base_url
      @session                       = new_session
    end

    def reconnect
      @session         = new_session
    end

    def headers
      @session.headers
    end

    def make_safe_request(path, &block)
      block.call
    rescue Faraday::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Faraday::ConnectionFailed
      begin
        reconnect
        block.call
      rescue Faraday::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

    def get(path, headers={})
      make_safe_request(path) do
        @session.get(path) do |req|
          req.headers = headers
        end
      end
    end

    def put(path, data, headers={})
      make_safe_request(path) do
        @session.put(path) do |req|
          req.headers = headers
          req.body = data
        end
      end
    end

    def post(path, data, headers={})
      make_safe_request(path) do
        @session.post(path) do |req|
          req.headers = headers
          req.body = data
        end
      end
    end

    def delete(path, headers={})
      make_safe_request(path) do
        @session.delete(path) do |req|
          req.headers = headers
        end
      end
    end

    private

    def new_session
      Faraday.new({url: @base_url}, &ActiveRestClient::Base.faraday_config)
    end

  end
end
