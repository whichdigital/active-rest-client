module ActiveRestClient
  module Caching
    module ClassMethods
      @@perform_caching = true

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
        @@cache_store = nil if value.nil? and return
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
        if cache_store && perform_caching
          key = "#{request.class_name}:#{request.original_url}"
          ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{key} - Trying to read from cache"
          value = cache_store.read(key)
          value = Marshal.load(value) rescue value
        end
      end

      def write_cached_response(request, response, result)
        return if result.is_a? Symbol
        return unless perform_caching
        return unless !result.respond_to?(:_status) || [200, 304].include?(result._status)
        headers = response.response_headers

        headers.keys.select{|h| h.is_a? String}.each do |key|
          headers[key.downcase.to_sym] = headers[key]
        end

        if cache_store && (headers[:etag] || headers[:expires])
          key = "#{request.class_name}:#{request.original_url}"
          ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{key} - Writing to cache"
          cached_response = CachedResponse.new(status:response.status, result:result)
          cached_response.etag = headers[:etag] if headers[:etag]
          cached_response.expires = Time.parse(headers[:expires]) rescue nil if headers[:expires]
          cache_store.write(key, Marshal.dump(cached_response), {}) if cached_response.etag.present? || cached_response.expires
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
