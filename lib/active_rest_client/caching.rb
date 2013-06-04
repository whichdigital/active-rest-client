module ActiveRestClient
  module Caching
    module ClassMethods
      @@perform_caching = false

      def perform_caching(value = nil)
        if value.nil?
          if @perform_caching.nil?
            @@perform_caching
          else
            @perform_caching
          end
        else
          @perform_caching = value
        end
      end

      def perform_caching=(value)
        @@perform_caching = value
        @perform_caching = value
      end

      def cache_store=(value)
        raise InvalidCacheStoreException.new("Cache store does not implement #read") unless value.respond_to?(:read)
        raise InvalidCacheStoreException.new("Cache store does not implement #write") unless value.respond_to?(:write)
        raise InvalidCacheStoreException.new("Cache store does not implement #fetch") unless value.respond_to?(:fetch)
        @@cache_store = value
      end

      def cache_store
        @@cache_store || (defined?(Rails) ? Rails.cache : nil)
      end

      def _reset_caching!
        @@perform_caching = false
        @perform_caching = false
        @@cache_store = nil
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
