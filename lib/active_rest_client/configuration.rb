module ActiveRestClient
  module Configuration
    module ClassMethods
      def base_url(value = nil)
        value ? @base_url = value : @base_url
      end

      def whiny_missing(value = nil)
        value ? @whiny_missing = value : @whiny_missing || false
      end

      def _reset_configuration!
        @base_url         = nil
        @whiny_missing    = nil
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  class InvalidCacheStoreException < StandardError ; end
end
