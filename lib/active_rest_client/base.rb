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

    def self._request(request, method = :get, params = nil)
      unless request.is_a? ActiveRestClient::Request
        mapped = {url:"DIRECT-CALLED-URL", method:method, options:{url:request}}
        request = Request.new(mapped, self)
      end
      request.call(params)
    end

    def self._lazy_request(request, method = :get, params = nil)
      unless request.is_a? ActiveRestClient::Request
        mapped = {url:"DIRECT-CALLED-URL", method:method, options:{url:request}}
        request = Request.new(mapped, self)
      end
      ActiveRestClient::LazyLoader.new(request, params)
    end

    def self._request_for(method_name, *args)
      if mapped = self._mapped_method(method_name)
        params = (args.first.is_a?(Hash) ? args.first : nil)
        request = Request.new(mapped, self, params)
        request
      else
        nil
      end
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
        name_sym = name.to_sym
        name = name.to_s

        if @attributes.has_key? name_sym
          @attributes[name_sym]
        else
          if name[/^lazy_/] && mapped = self.class._mapped_method(name_sym)
            raise ValidationFailedException.new unless valid?
            request = Request.new(mapped, self, args.first)
            ActiveRestClient::LazyLoader.new(request)
          elsif mapped = self.class._mapped_method(name_sym)
            raise ValidationFailedException.new unless valid?
            # params = (args.first.is_a?(Hash) ? args.first : nil)
            request = Request.new(mapped, self, args.first)
            request.call
          elsif self.class.whiny_missing
            raise NoAttributeException.new("Missing attribute #{name_sym}")
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
