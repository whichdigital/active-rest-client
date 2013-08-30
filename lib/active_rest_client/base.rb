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
        @attributes[k.to_sym] = v
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

    def method_missing(name, *args)
      if mapped = self.class._mapped_method(name)
        raise ValidationFailedException.new unless valid?
        request = Request.new(mapped, self)
        params = (args.first.is_a?(Hash) ? args.first : nil)
        request.call(params)
      elsif name.to_s[-1,1] == "="
        name = name.to_s.chop.to_sym
        @attributes[name] = args.first
        @dirty_attributes << name
      else
        name = name.to_sym

        # Handle self.class._mapped_method(name)

        if @attributes.has_key? name
          @attributes[name]
        else
          if self.class.whiny_missing
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
