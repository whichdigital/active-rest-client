require 'patron'

module ActiveRestClient

  class TimeoutException < StandardError ; end
  class ConnectionFailedException < StandardError ; end

  class Connection
    attr_accessor :session

    def initialize(base_url)
      @base_url                      = base_url
      @session                       = Patron::Session.new
      @session.timeout               = 10
      @session.base_url              = base_url
      @session.headers['User-Agent'] = "ActiveRestClient/#{ActiveRestClient::VERSION}"
      @session.headers['Connection'] = "Keep-Alive"
      @session.headers['Accept']     = "application/json"
    end

    def reconnect
      session          = Patron::Session.new
      session.timeout  = @session.timeout
      session.base_url = @session.base_url
      @session.headers.each do |k,v|
        session.headers[k] = v
      end
      @session         = session
    end

    def headers
      @session.headers
    end

    def make_safe_request(path, &block)
      block.call
    rescue Patron::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Patron::ConnectionFailed
      begin
        reconnect
        block.call
      rescue Patron::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

    def get(path)
      make_safe_request(path) do
        @session.get(path)
      end
    end

    def put(path, data)
      make_safe_request(path) do
        @session.put(path, data)
      end
    end

    def post(path, data)
      make_safe_request(path) do
        @session.post(path, data)
      end
    end

    def delete(path, data)
      make_safe_request(path) do
        @session.delete(path, data)
      end
    end

  end
end
