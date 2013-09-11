require "cgi"
require "oj"

module ActiveRestClient

  class Request
    attr_accessor :post_params, :get_params, :url, :path, :headers, :method, :object

    def initialize(method, object, params = {})
      @method                  = method
      @method[:options]        ||= {}
      @method[:options][:lazy] ||= []
      @object                  = object
      @params                  = params
      @headers                 = HeadersList.new
    end

    def object_is_class?
      !@object.respond_to?(:dirty?)
    end

    def class_name
      if object_is_class?
        @object.name
      else
        @object.class.name
      end
    end

    def base_url
      if object_is_class?
        @object.base_url
      else
        @object.class.base_url
      end
    end

    def verbose?
      if object_is_class?
        @object.verbose
      else
        @object.class.verbose
      end
    end

    def translator
      if object_is_class?
        @object.translator
      else
        @object.class.translator
      end
    end

    def call(explicit_parameters=nil)
      @instrumentation_name = "#{class_name}##{@method[:name]}"
      result = nil
      cached = nil
      ActiveSupport::Notifications.instrument("request_call.active_rest_client", :name => @instrumentation_name) do
        if @method[:options][:fake]
          ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Faked response found"
          return handle_response(OpenStruct.new(status:200, body:@method[:options][:fake], headers:{"X-ARC-Faked-Response" => "true"}))
        end
        @explicit_parameters = explicit_parameters
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
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Absolutely cached copy found"
            return handle_cached_response(cached)
          else
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Etag cached copy found"
            etag = cached.etag
          end
        end
        response = do_request(etag)
        result = handle_response(response)
        ActiveRestClient::Base.write_cached_response(self, response, result)
      end
      if result == :not_modified && cached
        cached.result
      else
        result
      end
    end

    def prepare_params
      params = @object._attributes rescue @params
      if params.is_a?(String) || params.is_a?(Fixnum)
        params = {id:params}
      end

      default_params = @method[:options][:defaults] || {}

      if @explicit_parameters
        params = @explicit_parameters
      end
      if @method[:method] == :get
        @get_params = default_params.merge(params || {})
        @post_params = nil
      else
        @post_params = default_params.merge(params || {})
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

    def do_request(etag)
      http_headers = {}
      http_headers["If-None-Match"] = etag if etag
      http_headers["Accept"] = "application/hal+json, application/json;q=0.5"
      headers.each do |key,value|
        value = value.join(",") if value.is_a?(Array)
        http_headers[key] = value
      end
      if @method[:options][:url]
        @url = @method[:options][:url]
        @method[:method] = :get
        if connection = ActiveRestClient::ConnectionManager.find_connection_for_url(@url)
          @url = @url.slice(connection.base_url.length, 255)
        else
          _, @base_url, @url = @url.match(%r{^(https?://[a-z\d\.:-]+?)(/.*)}).to_a
          connection = ActiveRestClient::ConnectionManager.get_connection(@base_url)
        end
      else
        connection = ActiveRestClient::ConnectionManager.get_connection(base_url)
      end
      ActiveRestClient::Logger.info "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Requesting #{connection.base_url}#{@url}"

      if verbose?
        ActiveRestClient::Logger.debug "ActiveRestClient Verbose Log:"
        http_headers.each do |k,v|
          ActiveRestClient::Logger.debug "  > #{k} : #{v}"
        end
        ActiveRestClient::Logger.debug "  > #{@request_body}"
      end

      case @method[:method]
      when :get
        response = connection.get(@url, http_headers)
      when :put
        response = connection.put(@url, @request_body, http_headers)
      when :post
        response = connection.post(@url, @request_body, http_headers)
      when :delete
        response = connection.delete(@url, @request_body, http_headers)
      else
        raise InvalidRequestException.new("Invalid method #{@method[:method]}")
      end

      if verbose?
        response.headers.each do |k,v|
          ActiveRestClient::Logger.debug "  < #{k} : #{v}"
        end
        ActiveRestClient::Logger.debug "  < #{response.body}"
      end

      response
    end

    def handle_cached_response(cached)
      if cached.result.is_a? ActiveRestClient::ResultIterator
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
      if response.status == 304
        ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Etag copy is the same as the server"
        return :not_modified
      end
      ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Response received #{response.body.size} bytes"

      @response = response

      body = Oj.load(response.body) || {}
      body = translator.send(@method[:name], body) rescue body
      if body.is_a? Array
        result = ActiveRestClient::ResultIterator.new(response.status)
        body.each do |json_object|
          result << new_object(json_object)
        end
      else
        result = new_object(body)
        result._status = response.status
        unless object_is_class?
          @object._copy_from(result)
          result = @object
        end
      end

      response.status ||= 200
      if response.status == 401
        raise HTTPUnauthorisedClientException.new(status:response.status, result:result)
      elsif response.status == 403
        raise HTTPForbiddenClientException.new(status:response.status, result:result)
      elsif response.status == 404
        raise HTTPNotFoundClientException.new(status:response.status, result:result)
      elsif (400..499).include? response.status
        raise HTTPClientException.new(status:response.status, result:result)
      elsif (500..599).include? response.status
        raise HTTPServerException.new(status:response.status, result:result)
      end

      result
    rescue Oj::ParseError
      raise ResponseParseException.new(status:response.status, body:response.body)
    end

    def new_object(attributes, name = nil)
      @method[:options][:has_many] ||= {}
      if @method[:options][:has_many][name]
        object = @method[:options][:has_many][name].new
      else
        if object_is_class?
          object = @object.new
        else
          object = @object.class.new
        end
      end

      if hal_response? && name.nil?
        attributes = handle_hal_links_embedded(object, attributes)
      end

      attributes.each do |k,v|
        k = k.to_sym
        if @method[:options][:lazy].include?(k)
          object._attributes[k] = ActiveRestClient::LazyAssociationLoader.new(k, v, self)
        elsif v.is_a? Hash
          object._attributes[k] = new_object(v, k)
        elsif v.is_a? Array
          object._attributes[k] = ActiveRestClient::ResultIterator.new
          v.each do |item|
            if item.is_a? Hash
              object._attributes[k] << new_object(item, k)
            else
              object._attributes[k] << item
            end
          end
        else
          object._attributes[k] = v
        end
      end
      object.clean!

      object
    end

    def hal_response?
      _, content_type = @response.headers.detect{|k,v| k.downcase == "content-type"}
      faked_response = @response.headers.detect{|k,v| k.downcase == "x-arc-faked-response"}
      content_type && content_type[%r{application\/hal\+json}i] || faked_response
    end

    def handle_hal_links_embedded(object, attributes)
      if attributes["_links"]
        attributes["_links"].each do |key, value|
          if value.is_a?(Array)
            object._attributes[key.to_sym] ||= ActiveRestClient::ResultIterator.new
            value.each do |element|
              begin
                embedded_version = attributes["_embedded"][key].detect{|embed| embed["_links"]["self"]["href"] == element["href"]}
                object._attributes[key.to_sym] << new_object(embedded_version, key)
              rescue NoMethodError
                object._attributes[key.to_sym] << ActiveRestClient::LazyAssociationLoader.new(key, element, self)
              end
            end
          else
            begin
              embedded_version = attributes["_embedded"][key]
              object._attributes[key.to_sym] = new_object(embedded_version, key)
            rescue NoMethodError
              object._attributes[key.to_sym] = ActiveRestClient::LazyAssociationLoader.new(key, value, self)
            end
          end
        end
        attributes.delete("_links")
        attributes.delete("_embedded")
      end

      attributes
    end
  end

  class InvalidRequestException < StandardError ; end
  class ResponseParseException < StandardError
    attr_accessor :status, :body
    def initialize(options)
      @status = options[:status]
      @body = options[:body]
    end
  end

  class HTTPException < StandardError
    attr_accessor :status, :result
    def initialize(options)
      @status = options[:status]
      @result = options[:result]
    end
  end
  class HTTPClientException < HTTPException ; end
  class HTTPUnauthorisedClientException < HTTPClientException ; end
  class HTTPForbiddenClientException < HTTPClientException ; end
  class HTTPNotFoundClientException < HTTPClientException ; end
  class HTTPServerException < HTTPException ; end

end
