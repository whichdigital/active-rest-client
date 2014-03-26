module ActiveRestClient
  class Base
    include Mapping
    include Configuration
    include RequestFiltering
    include Validation
    include Caching
    include Recording

    attr_accessor :_status

    instance_methods.each do |m|
      next unless %w{display errors presence load require hash untrust trust freeze method enable_warnings with_warnings suppress capture silence quietly debugger breakpoint}.map(&:to_sym).include? m
      undef_method m
    end

    def initialize(attrs={})
      @attributes = {}
      @dirty_attributes = Set.new

      raise Exception.new("Cannot instantiate Base class") if self.class.name == "ActiveRestClient::Base"

      attrs.each do |attribute_name, attribute_value|
        attribute_name = attribute_name.to_sym
        if attribute_value.to_s[/\d{4}\-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/]
          @attributes[attribute_name] = DateTime.parse(attribute_value)
        else
          @attributes[attribute_name] = attribute_value
        end
        @dirty_attributes << attribute_name
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
      prepare_direct_request(request, method).call(params)
    end

    def self._plain_request(request, method = :get, params = nil)
      prepare_direct_request(request, method, plain:true).call(params)
    end

    def self._lazy_request(request, method = :get, params = nil)
      ActiveRestClient::LazyLoader.new(prepare_direct_request(request, method), params)
    end

    def self.prepare_direct_request(request, method, options={})
      unless request.is_a? ActiveRestClient::Request
        options[:plain] ||= false
        mapped = {url:"DIRECT-CALLED-#{request}", method:method, options:{url:request, plain:options[:plain]}}

        request = Request.new(mapped, self)
      end
      request
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

    def each
      @attributes.each do |key, value|
        yield key, value
      end
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

    def respond_to_missing?(method_name, include_private = false)
      @attributes.has_key? method_name.to_sym
    end
  end

  class NoAttributeException < StandardError ; end
  class ValidationFailedException < StandardError ; end
end
