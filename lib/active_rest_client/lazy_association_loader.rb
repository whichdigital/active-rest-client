module ActiveRestClient
  class LazyAssociationLoader
    include Enumerable

    def initialize(name, value, request)
      @name = name
      @request = request
      @object = nil
      if value.is_a? Array
        @subloaders = value.map {|url| LazyAssociationLoader.new(name, url, request)}
      elsif value.is_a?(Hash) && value.has_key?("url")
        @url = value["url"]
      elsif value.is_a?(Hash) && value.has_key?("href") # HAL
        @url = value["href"]
      elsif value.is_a? String
        @url = value
      else
        raise InvalidLazyAssociationContentException.new("Invalid content for #{@name}, expected Array, String or Hash containing 'url' key")
      end
    end

    def size
      @subloaders.size
    end

    def each
      if @subloaders
        @subloaders.each do |subloader|
          yield subloader
        end
      end
    end

    def method_missing(name, *args)
      if @object.nil?
        @request.method = @request.method.dup
        @request.method[:options][:url] = @url
        request = ActiveRestClient::Request.new(@request.method, @request.object)
        @object = request.call
      end
      if @object
        @object.send(name, *args)
      end
    end
  end

  class InvalidLazyAssociationContentException < Exception ; end

end
