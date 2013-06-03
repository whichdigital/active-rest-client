module ActiveRestClient
  class Base
    include Mapping
    include Configuration
    include ConnectionManager
    include RequestFiltering

    def initialize(attrs={})
      raise Exception.new("Cannot instantiate Base class") if self.class.name == "ActiveRestClient::Base"

      @attributes = {}
      @dirty_attributes = Set.new

      attrs.each do |k,v|
        @attributes[k.to_sym] = v
        @dirty_attributes << name
      end
    end

    def _clean!
      @dirty_attributes = Set.new
    end

    def _empty!
      @attributes = {}
    end

    def _attributes
      @attributes
    end

    def dirty?
      @dirty_attributes.size > 0
    end

    def method_missing(name, *args)
      if mapped = self.class._mapped_method(name)
        request = Request.new(mapped, self)
        request.call
      elsif name.to_s[-1,1] == "="
        name = name.to_s.chop.to_sym
        @attributes[name] = args.first
        @dirty_attributes << name
      else
        name = name.to_sym
        if @attributes.has_key? name
          @attributes[name]
        else
          if @@whiny_missing
            raise NoAttributeError.new("Missing attribute #{name}")
          else
            nil
          end
        end
      end
    end
  end

  class NoAttributeError < Exception ; end
end
