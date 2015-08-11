require 'active_support/hash_with_indifferent_access'

module ActiveRestClient
  class LazyAssociationLoader
    include Enumerable

    def initialize(name, value, request, options = {})
      @name = name
      class_to_map = request.method[:options][:lazy][name] rescue nil
      @request = class_to_map.nil? ? request : ActiveRestClient::Request.new(class_to_map._mapped_method(:find), class_to_map.new, options)
      @object = nil
      @options = options
      if value.is_a? Array
        @subloaders = value.map {|url| LazyAssociationLoader.new(name, url, request, options)}
      elsif value.is_a?(Hash) && (value.has_key?("url") || value.has_key?(:url))
        @url = (value["url"] || value[:url])
      elsif value.is_a?(Hash) && (value.has_key?("href") || value.has_key?(:href)) # HAL
        @url = (value["href"] || value[:href])
        @_hal_attributes = HashWithIndifferentAccess.new(value)
      elsif value.is_a?(Hash)
        mapped = {}
        value.each do |k,v|
          mapped[k.to_sym] = LazyAssociationLoader.new(name, v, request, options)
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
        method = MultiJson.load(MultiJson.dump(@request.method),:symbolize_keys => true)
        method[:method] = :get
        method[:options][:url] = @url
        method[:options][:overridden_name] = @options[:overridden_name]
        request = ActiveRestClient::Request.new(method, @request.object)
        request.url = request.forced_url = @url
        @object = request.call
      end
    end
  end

  class InvalidLazyAssociationContentException < Exception ; end

end
