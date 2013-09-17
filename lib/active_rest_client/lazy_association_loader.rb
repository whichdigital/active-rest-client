require 'active_support/hash_with_indifferent_access'

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
        @_hal_attributes = HashWithIndifferentAccess.new(value)
      elsif value.is_a?(Hash)
        mapped = {}
        value.each do |k,v|
          mapped[k.to_sym] = LazyAssociationLoader.new(name, v, request)
        end
        @subloaders = mapped
        # Need to also ensure that the hash/wrapped object is returned when the property is accessed
      elsif value.is_a? String
        @url = value
      else
        raise InvalidLazyAssociationContentException.new("Invalid content for #{@name}, expected Array, String or Hash containing 'url' key")
      end
    end

    def _hal_attributes(key)
      @_hal_attributes[key]
    end

    def size
      if @subloaders
        @subloaders.size
      else
        ensure_lazy_loaded
        @object.size
      end
    end

    def each
      if @subloaders
        if @subloaders.is_a? Array
          @subloaders.each do |loader|
            yield loader
          end
        elsif @subloaders.is_a? Hash
          @subloaders.each do |key,value|
            yield key, value
          end
        end
      else
        ensure_lazy_loaded
        @object.each do |obj|
          yield obj
        end
      end
    end

    def keys
      @subloaders.keys
    end

    def method_missing(name, *args)
      if @subloaders.is_a? Hash
        return @subloaders[name.to_sym]
      end
      ensure_lazy_loaded
      if @object
        @object.send(name, *args)
      end
    end

    private

    def ensure_lazy_loaded
      if @object.nil?
        @request.method[:method] = :get
        @request.method[:options][:url] = @url
        request = ActiveRestClient::Request.new(@request.method, @request.object)
        @object = request.call
      end
    end
  end

  class InvalidLazyAssociationContentException < Exception ; end

end
