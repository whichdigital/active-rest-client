module ActiveRestClient
  module ConnectionManager

    module ClassMethods
      @@_connections = {}

      def get_connection(base_url)
        @@_connections[base_url] ||= Connection.new(base_url)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
