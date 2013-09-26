module ActiveRestClient
  class LazyLoader
    def initialize(request, params = nil)
      @request = request
      @params = params
      @result = nil
    end

    def method_missing(name, *args)
      if @result.nil?
        @result = @request.call(@params)
      end
      @result.send(name, *args)
    end

    def respond_to?(name)
      if @result.nil?
        @result = @request.call(@params)
      end
      @result.respond_to?(name)
    end
  end
end
