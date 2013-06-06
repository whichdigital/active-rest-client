module ActiveRestClient
  module Configuration
    module ClassMethods
      @@base_url = nil

      def base_url(value = nil)
        if value.nil?
          if @base_url.nil?
            @@base_url
          else
            @base_url
          end
        else
          value = value.gsub(/\/$/, '')
          @base_url = value
        end
      end

      def base_url=(value)
        value = value.gsub(/\/$/, '')
        @@base_url = value
        @base_url = value
      end

      def whiny_missing(value = nil)
        value ? @whiny_missing = value : @whiny_missing || false
      end

      def _reset_configuration!
        @base_url         = nil
        @@base_url        = nil
        @whiny_missing    = nil
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  class InvalidCacheStoreException < StandardError ; end
end
