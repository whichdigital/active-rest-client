module ActiveRestClient
  module ConnectionManager

    module ClassMethods
      def get_connection
        @@_connection ||= Connection.new(base_url)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
