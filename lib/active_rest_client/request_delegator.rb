module ActiveRestClient
  class RequestDelegator < Delegator
    def initialize(obj)
      super
      @delegate_obj = obj
    end

    def __getobj__
      @delegate_obj
    end

    def __setobj__(obj)
      @delegate_obj = obj
    end

    def class
      @delegate_obj.class
    end

    def method_missing(name, *args, &block)
      # Handles issue with private method 'test' on base Ruby Object
      return @delegate_obj.test if name.to_sym == :test

      # Forward request to delegate
      @delegate_obj.send(name, *args, &block)
    end

    def kind_of?(obj)
      @delegate_obj.kind_of?(obj)
    end

    def is_a?(obj)
      @delegate_obj.is_a?(obj)
    end

    def instance_of?(obj)
      @delegate_obj.instance_of?(obj)
    end

    def _delegate?
      return true
    end
  end
end
