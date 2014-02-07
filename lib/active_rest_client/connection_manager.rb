module ActiveRestClient
  class ConnectionManager
    def self.reset!
      Thread.current[:_connections]={}
    end

    def self.get_connection(base_url)
      raise Exception.new("Nil base URL passed to ConnectionManager.get_connection") if base_url.nil?
      Thread.current[:_connections] ||= {}
      Thread.current[:_connections][base_url] ||= Connection.new(base_url)
      Thread.current[:_connections][base_url]
    end

    def self.find_connection_for_url(url)
      Thread.current[:_connections] ||= {}
      found = Thread.current[:_connections].keys.detect {|key| url[0,key.length] == key}
      Thread.current[:_connections][found] if found
    end

  end
end
