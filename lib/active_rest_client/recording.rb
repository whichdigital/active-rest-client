module ActiveRestClient
  module Recording
    module ClassMethods
      @record_response = nil

      def record_response(url = nil, response = nil, &block)
        if url && response && @record_response
          @record_response.call(url, response)
        elsif block
          @record_response = block
        end
      end

      def record_response?
        !!@record_response
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
