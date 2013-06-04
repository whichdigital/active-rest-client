require "cgi"
require "oj"

module ActiveRestClient

  class Request
    attr_accessor :post_params, :get_params, :url, :path

    def initialize(method, object, params = {})
      @method = method
      @object = object
      @params = params
    end

    def object_is_class?
      @object.respond_to?(:get_connection)
    end

    def class_name
      if object_is_class?
        @object.name
      else
        @object.class.name
      end
    end

    def call
      connection = @object.get_connection || @object.class.get_connection rescue @object.class.get_connection
      prepare_params
      prepare_url
      if object_is_class?
        @object.send(:_filter_request, @method[:name], self)
      end
      append_get_parameters
      prepare_request_body
      cached = ActiveRestClient::Base.read_cached_response(self)
      if cached
        if cached.expires && cached.expires > Time.now
          return handle_cached_response(cached)
        else
          etag = cached.etag
        end
      end
      headers = {}
      headers["If-None-Match"] = etag if etag
      case @method[:method]
      when :get
        response = connection.get(@url, headers)
      when :put
        response = connection.put(@url, @request_body, headers)
      when :post
        response = connection.post(@url, @request_body, headers)
      when :delete
        response = connection.delete(@url, @request_body, headers)
      else
        raise InvalidRequestException.new("Invalid method #{@method[:method]}")
      end

      result = handle_response(response)
      ActiveRestClient::Base.write_cached_response(self, response, result)
      if result == :not_modified && cached
        cached.result
      else
        result
      end
    end

    def prepare_params
      params = @object._attributes rescue @params
      if @method[:method] == :get
        @get_params = params || []
        @post_params = nil
      else
        @post_params = params || []
        @get_params = {}
      end
    end

    def prepare_url
      @url = @method[:url].dup
      matches = @url.scan(/(:[a-z_-]+)/)
      matches.each do |token|
        token = token.first[1,999]
        target = @get_params.delete(token.to_sym) || @post_params.delete(token.to_sym) || ""
        @url.gsub!(":#{token}", target.to_s)
      end
    end

    def append_get_parameters
      if @method[:method] == :get && @get_params.any?
        params = @get_params.map {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}
        @url += "?" + params.sort * "&"
      end
    end

    def prepare_request_body
      @request_body = (@post_params || {}).map {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.sort * "&"
    end

    def handle_cached_response(cached)
      # TODO handle cached.status
      if cached.result.is_a? Array # TODO replace with iterator
        cached.result
      else
        if object_is_class?
          cached.result
        else
          @object._copy_from(cached.result)
          @object
        end
      end
    end

    def handle_response(response)
      return :not_modified if response.status == 304
      body = Oj.load(response.body) || {}
      if body.is_a? Array
        result = []
        body.each do |json_object|
          result << new_object(json_object)
        end
      else
        result = new_object(body)
        unless object_is_class?
          @object._copy_from(result)
          result = @object
        end
      end

      # TODO - handle response codes
      # if response.status == 200
      #   result
      # end

      result
    end

    def new_object(attributes)
      if @method[:class]
        object = @method[:class].new
      else
        if object_is_class?
          object = @object.new
        else
          object = @object.class.new
        end
      end

      attributes.each do |k,v|
        k = k.to_sym
        if v.is_a? Hash
          object._attributes[k] = new_object(v)
        elsif v.is_a? Array
          object._attributes[k] = []  # TODO replace with iterator
          v.each do |item|
            if item.is_a? Hash
              object._attributes[k] << new_object(item)
            else
              object._attributes[k] << item
            end
          end
        else
          object._attributes[k] = v
        end
        object.clean!
      end

      object
    end

  end

  class InvalidRequestException < Exception ; end

end
