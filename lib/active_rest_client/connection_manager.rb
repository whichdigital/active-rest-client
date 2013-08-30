module ActiveRestClient
  class ConnectionManager
    def self.reset!
      @_connections = {}
    end

    def self.get_connection(base_url)
      @_connections ||= {}
      @_connections[base_url] ||= Connection.new(base_url)
      @_connections[base_url]
    end

    def self.find_connection_for_url(url)
      @_connections ||= {}
      found = @_connections.keys.detect {|key| url[0,key.length] == key}
      @_connections[found] if found
    end

  end
end
