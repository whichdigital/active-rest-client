module ActiveRestClient
  module Configuration
    module ClassMethods
      @@base_url = nil
      @lazy_load = false

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
        ActiveRestClient::Logger.info "\033[1;4;32m#{name}\033[0m Base URL set to be #{value}"
        value = value.gsub(/\/+$/, '')
        @@base_url = value
      end

      def adapter=(adapter)
        ActiveRestClient::Logger.info "\033[1;4;32m#{name}\033[0m Adapter set to be #{adapter}"
        @adapter = adapter
      end

      def adapter
        @adapter ||= :patron
      end

      def faraday_config(&block)
        if block
          @faraday_config = block
        else
          @faraday_config ||= default_faraday_config
        end
      end

      def lazy_load!
        @lazy_load = true
      end

      def lazy_load?
        @lazy_load || false
      end

      def whiny_missing(value = nil)
        value ? @whiny_missing = value : @whiny_missing || false
      end

      def verbose!
        @verbose = true
      end

      def verbose(value = nil)
        value ? @verbose = value : @verbose || false
      end

      def translator(value = nil)
        ActiveRestClient::Logger.warn("DEPRECATION: The translator functionality of ActiveRestClient has been replaced with proxy functionality, see https://github.com/whichdigital/active-rest-client#proxying-apis for more information") unless value.nil?
        value ? @translator = value : @translator || nil
      end

      def proxy(value = nil)
        value ? @proxy = value : @proxy || nil
      end

      def _reset_configuration!
        @base_url         = nil
        @@base_url        = nil
        @whiny_missing    = nil
        @lazy_load        = false
        @faraday_config   = default_faraday_config
        @adapter          = :patron
      end

      private

      def default_faraday_config
        Proc.new do |faraday|
          faraday.adapter(adapter)
          faraday.options.timeout       = 10
          faraday.options.open_timeout  = 10
          faraday.headers['User-Agent'] = "ActiveRestClient/#{ActiveRestClient::VERSION}"
          faraday.headers['Connection'] = "Keep-Alive"
          faraday.headers['Accept']     = "application/json"
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end

  class InvalidCacheStoreException < StandardError ; end
end
