module ActiveRestClient
  module Configuration

    module ClassMethods
      def base_url(value = nil)
        value ? @base_url = value : @base_url
      end

      def whiny_missing(value = nil)
        value ? @whiny_missing = value : @whiny_missing
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
