module ActiveRestClient
  class Base
    include Mapping
    include Configuration
    include RequestFiltering
    include Validation
    include Caching

    attr_accessor :_status

    def initialize(attrs={})
      raise Exception.new("Cannot instantiate Base class") if self.class.name == "ActiveRestClient::Base"

      @attributes = {}
      @dirty_attributes = Set.new

      attrs.each do |k,v|
        if v.to_s[/\d{4}\-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/]
          @attributes[k.to_sym] = DateTime.parse(v)
        else
          @attributes[k.to_sym] = v
        end
        @dirty_attributes << k.to_sym
      end
    end

    def _clean!
      @dirty_attributes = Set.new
    end

    def _attributes
      @attributes
    end

    def _copy_from(result)
      @attributes =  result._attributes
      @_status = result._status
    end

    def dirty?
      @dirty_attributes.size > 0
    end

    def self._request(url, method = :get, params={})
      mapped = {url:"DIRECT-CALLED-URL", method:method, options:{url:url}}
      request = Request.new(mapped, self)
      request.call(params)
    end

    def [](key)
      @attributes[key.to_sym]
    end

    def []=(key, value)
      @attributes[key.to_sym] = value
      @dirty_attributes << key
    end

    def method_missing(name, *args)
      if name.to_s[-1,1] == "="
        name = name.to_s.chop.to_sym
        @attributes[name] = args.first
        @dirty_attributes << name
      else
        name = name.to_sym

        if @attributes.has_key? name
          @attributes[name]
        else
          if mapped = self.class._mapped_method(name)
            raise ValidationFailedException.new unless valid?
            request = Request.new(mapped, self)
            params = (args.first.is_a?(Hash) ? args.first : nil)
            request.call(params)
          elsif self.class.whiny_missing
            raise NoAttributeException.new("Missing attribute #{name}")
          else
            nil
          end
        end
      end
    end
  end

  class NoAttributeException < StandardError ; end
  class ValidationFailedException < StandardError ; end
end
