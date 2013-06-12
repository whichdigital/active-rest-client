module ActiveRestClient
  module ConnectionManager

    module ClassMethods
      def get_connection
        @_connections ||= {}
        @_connections[base_url] ||= Connection.new(base_url)
        @_connections[base_url]
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
