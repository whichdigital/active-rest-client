module ActiveRestClient
  class Base
    include Mapping
    include Configuration
    include ConnectionManager

    def initialize(attrs={})
      raise Exception.new("Cannot instantiate Base class") if self.class.name == "ActiveRestClient::Base"

      @attributes = {}
      attrs.each do |k,v|
        @attributes[k.to_sym] = Attribute.new(v)
      end
    end

    def clean!
      @attributes.each do |k,v|
        v.clean!
      end
    end

    def attributes
      @attributes
    end

    def method_missing(name, *args)
      if mapped = self.class._mapped_method(name)
        request = Request.new(mapped, self)
        request.call
      elsif name.to_s[-1,1] == "="
        name = name.to_s.chop.to_sym
        @attributes[name] = Attribute.new(args.first)
      else
        name = name.to_sym
        if @attributes.has_key? name
          @attributes[name]
        else
          if @@whiny_missing
            raise NoAttributeError.new("Missing attribute #{name}")
          else
            Attribute.new(nil, true)
          end
        end
      end
    end
  end

  class NoAttributeError < Exception ; end
end
