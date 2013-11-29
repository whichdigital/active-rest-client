module ActiveRestClient
  class ResultIterator
    include Enumerable

    attr_accessor :_status
    attr_reader :items

    def initialize(status = nil)
      @_status = status
      @items = []
    end

    def <<(item)
      @items << item
    end

    def size
      @items.size
    end

    def index(value)
      @items.index(value)
    end

    def empty?
      size == 0
    end

    def each
      @items.each do |el|
        yield el
      end
    end

    def last
      @items.last
    end

    def [](key)
      @items[key]
    end

    def shuffle
      @items = @items.shuffle
      self
    end

    def parallelise(method=nil)
      collected_responses = []
      threads = []
      @items.each do |item|
        threads << Thread.new do
          ret = item.send(method) if method
          ret = yield(item) if block_given?
          Thread.current[:response] = ret
        end
      end
      threads.each do |t|
        t.join
        collected_responses << t[:response]
      end
      collected_responses
    end

  end
end
