module ActiveRestClient
  class ResultIterator
    include Enumerable

    attr_accessor :_status

    def initialize(status = nil)
      @_status = status
      @items = []
    end

    def <<(item)
      @items << item
    end

    def each
      @items.each do |el|
        yield el
      end
    end

    def last
      @items.last
    end

  end
end
