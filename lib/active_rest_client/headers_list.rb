module ActiveRestClient
  class HeadersList
    STORE_MULTIPLE_VALUES = ["set-cookie"]
    def initialize
      @store = {}
    end

    def []=(key,value)
      key = find_existing(key)
      if STORE_MULTIPLE_VALUES.include?(key.downcase)
        @store[key] ||= []
        @store[key] << value
      else
        @store[key] = value
      end
    end

    def [](key)
      key = find_existing(key)
      @store[key]
    end

    def each(split_multiple_headers = false)
      @store.keys.each do |key|
        value = @store[key]
        if value.is_a?(Array) && split_multiple_headers
          value.each do |inner_value|
            yield(key, inner_value)
          end
        else
          yield(key, value)
        end
      end
    end

    private

    def find_existing(key)
      key_downcase = key.downcase
      @store.keys.each do |found_key|
        return found_key if found_key.downcase == key_downcase
      end
      key
    end

  end
end
