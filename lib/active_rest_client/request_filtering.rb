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
        _handle_super_class_filters(name, request)
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

      def _handle_super_class_filters(name, request)
        @parents ||= []
        @parents.each do |parent|
          parent._filter_request(name, request)
        end
      end

      def _parents
        @parents ||= []
      end

      def inherited(subclass)
        subclass._parents << self
        super
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
