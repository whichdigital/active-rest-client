module ActiveRestClient
  module RequestFiltering
    module ClassMethods
      def before_request(method_name = nil, &block)
        @before_filters ||= []
        if block
          @before_filters << block
        elsif method_name
          @before_filters << method_name
        end
      end

      def after_request(method_name = nil, &block)
        @after_filters ||= []
        if block
          @after_filters << block
        elsif method_name
          @after_filters << method_name
        end
      end

      def _filter_request(type, name, param)
        _handle_super_class_filters(type, name, param)
        filters = (type == :before ? @before_filters : @after_filters)
        filters ||= []
        filters.each do |filter|
          if filter.is_a? Symbol
            if self.respond_to?(filter)
              self.send(filter, name, param)
            else
              instance = self.new
              instance.send(filter, name, param)
            end
          else
            filter.call(name, param)
          end
        end
      end

      def _handle_super_class_filters(type, name, request)
        @parents ||= []
        @parents.each do |parent|
          parent._filter_request(type, name, request)
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
