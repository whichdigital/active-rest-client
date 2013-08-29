module ActiveRestClient
  class LazyLoader
    def initialize(request)
      @request = request
      @result = nil
    end

    def method_missing(name, *args)
      if @result.nil?
        @result = @request.call
      end
      @result.send(name, *args)
    end

    def respond_to?(name)
      if @result.nil?
        @result = @request.call
      end
      @result.respond_to?(name)
    end
  end
end
