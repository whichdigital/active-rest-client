module ActiveRestClient
  class Attribute
    attr_accessor :value
    attr_writer :dirty

    def initialize(value, dirty = true)
      @value = value
      @dirty = dirty
    end

    def dirty?
      @dirty
    end

    def clean!
      @dirty = false
    end

    def to_s
      @value
    end
  end
end
