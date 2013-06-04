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
        rails_cache_store = if Object.const_defined?(:Rails)
          ::Rails.cache
        else
          nil
        end
        (@@cache_store rescue nil) || rails_cache_store
      end

      def _reset_caching!
        @@perform_caching = false
        @perform_caching = false
        @@cache_store = nil
      end

      def read_cached_response(request)
        if cache_store
          key = "#{request.class_name}:#{request.url}"
          cache_store.read(key)
        end
      end

      def write_cached_response(request, response, result)
        if cache_store && (response.headers[:etag] || response.headers[:expires])
          key = "#{request.class_name}:#{request.url}"
          cached_response = CachedResponse.new(status:response.status, result:result)
          cached_response.etag = response.headers[:etag] if response.headers[:etag]
          cached_response.expires = Time.parse(response.headers[:expires]) if response.headers[:expires]

          options = {}
          options[:expires_in] = cached_response.expires - Time.now if cached_response.expires
          cache_store.write(key, cached_response, options)
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end

  class CachedResponse
    attr_accessor :status, :result, :etag, :expires

    def initialize(options)
      @status = options[:status]
      @result = options[:result]
      @etag = options[:etag]
      @expires = options[:expires]
    end
  end
end
