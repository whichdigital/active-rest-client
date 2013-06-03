module ActiveRestClient
  module RequestFiltering

    module ClassMethods
      def before_request(method_name = nil, &block)
        @filters ||= []
        if block
          @filters << block
        elsif method_name
          @filters << method_name
        end
      end

      def _filter_request(name, request)
        @filters ||= []
        @filters.each do |filter|
          if filter.is_a? Symbol
            if self.respond_to?(filter)
              self.send(filter, name, request)
            else
              instance = self.new
              instance.send(filter, name, request)
            end
          else
            filter.call(name, request)
          end
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
