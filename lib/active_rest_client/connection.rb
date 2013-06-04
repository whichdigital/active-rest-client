require 'patron'

module ActiveRestClient

  class TimeoutException < Exception ; end
  class ConnectionFailedException < Exception ; end

  class Connection
    attr_accessor :session

    def initialize(base_url)
      @base_url                      = base_url
      @session                       = Patron::Session.new
      @session.timeout               = 10
      @session.base_url              = base_url
      @session.headers['User-Agent'] = "ActiveRestClient/#{ActiveRestClient::VERSION}"
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

    def get(path)
      @session.get(path)
    rescue Patron::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Patron::ConnectionFailed
      begin
        reconnect
        @session.get(path)
      rescue Patron::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

    def put(path, data)
      @session.put(path, data)
    rescue Patron::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Patron::ConnectionFailed
      begin
        reconnect
        @session.put(path, data)
      rescue Patron::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

    def post(path, data)
      @session.post(path, data)
    rescue Patron::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Patron::ConnectionFailed
      begin
        reconnect
        @session.post(path, data)
      rescue Patron::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

    def delete(path, data)
      @session.delete(path, data)
    rescue Patron::TimeoutError
      raise ActiveRestClient::TimeoutException.new("Timed out getting #{@base_url}#{path}")
    rescue Patron::ConnectionFailed
      begin
        reconnect
        @session.delete(path, data)
      rescue Patron::ConnectionFailed
        raise ActiveRestClient::ConnectionFailedException.new("Unable to connect to #{@base_url}#{path}")
      end
    end

  end
end
