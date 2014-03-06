require "cgi"
require "multi_json"

module ActiveRestClient

  class Request
    attr_accessor :post_params, :get_params, :url, :path, :headers, :method, :object, :body, :forced_url, :original_url

    def initialize(method, object, params = {})
      @method                  = method
      @method[:options]        ||= {}
      @method[:options][:lazy] ||= []
      @overriden_name          = @method[:options][:overriden_name]
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

    def original_object_class
      if object_is_class?
        @object
      else
        @object.class
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

    def proxy
      if object_is_class?
        @object.proxy
      else
        @object.class.proxy
      end
    rescue
      nil
    end

    def http_method
      @method[:method]
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
        @body = nil
        prepare_params
        prepare_url
        if object_is_class?
          @object.send(:_filter_request, @method[:name], self)
        else
          @object.class.send(:_filter_request, @method[:name], self)
        end
        append_get_parameters
        prepare_request_body
        self.original_url = self.url
        cached = original_object_class.read_cached_response(self)
        if cached
          if cached.expires && cached.expires > Time.now
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Absolutely cached copy found"
            return handle_cached_response(cached)
          elsif cached.etag.to_s != "" #present? isn't working for some reason
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Etag cached copy found with etag #{cached.etag}"
            etag = cached.etag
          end
        end
        response = if proxy
          proxy.handle(self) do |request|
            request.do_request(etag)
          end
        else
          do_request(etag)
        end
        if object_is_class? && @object.record_response?
          @object.record_response(self.url, response)
        end
        result = handle_response(response)
        if result == :not_modified && cached
          result = cached.result
        end
        original_object_class.write_cached_response(self, response, result)
        result
      end
    end

    def prepare_params
      params = @params || @object._attributes rescue {}
      if params.is_a?(String) || params.is_a?(Fixnum)
        params = {id:params}
      end

      default_params = @method[:options][:defaults] || {}

      if @explicit_parameters
        params = @explicit_parameters
      end
      if http_method == :get
        @get_params = default_params.merge(params || {})
        @post_params = nil
      else
        @post_params = default_params.merge(params || {})
        @get_params = {}
      end
    end

    def prepare_url
      if @forced_url && @forced_url.present?
        @url = @forced_url
      else
        @url = @method[:url].dup
        matches = @url.scan(/(:[a-z_-]+)/)
        @get_params ||= {}
        @post_params ||= {}
        matches.each do |token|
          token = token.first[1,999]
          target = @get_params.delete(token.to_sym) || @post_params.delete(token.to_sym) || @get_params.delete(token.to_s) || @post_params.delete(token.to_s) || ""
          @url.gsub!(":#{token}", target.to_s)
        end
      end
    end

    def append_get_parameters
      if @get_params.any?
        params = @get_params.map {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}
        @url += "?" + params.sort * "&"
      end
    end

    def prepare_request_body(params = nil)
      @body ||= (params || @post_params || {}).map {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.sort * "&"
    end

    def do_request(etag)
      http_headers = {}
      http_headers["If-None-Match"] = etag if etag
      http_headers["Accept"] = "application/hal+json, application/json;q=0.5"
      headers.each do |key,value|
        value = value.join(",") if value.is_a?(Array)
        http_headers[key] = value
      end
      if @method[:options][:url] || @forced_url
        @url = @method[:options][:url]
        @url = @forced_url if @forced_url
        if connection = ActiveRestClient::ConnectionManager.find_connection_for_url(@url)
          @url = @url.slice(connection.base_url.length, 255)
        else
          parts = @url.match(%r{^(https?://[a-z\d\.:-]+?)(/.*)}).to_a
          if (parts.empty?) # Not a full URL, so use hostname/protocol from existing base_url
            uri = URI.parse(base_url)
            @base_url = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port != 80 && uri.port != 443}"
          else
            _, @base_url, @url = parts
          end
          connection = ActiveRestClient::ConnectionManager.get_connection(@base_url)
        end
      else
        connection = ActiveRestClient::ConnectionManager.get_connection(base_url)
      end
      ActiveRestClient::Logger.info "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Requesting #{connection.base_url}#{@url}"

      if verbose?
        ActiveRestClient::Logger.debug "ActiveRestClient Verbose Log:"
        ActiveRestClient::Logger.debug "  > GET #{@url} HTTP/1.1"
        http_headers.each do |k,v|
          ActiveRestClient::Logger.debug "  > #{k} : #{v}"
        end
        ActiveRestClient::Logger.debug "  > #{@body}"
      end

      case http_method
      when :get
        response = connection.get(@url, http_headers)
      when :put
        response = connection.put(@url, @body, http_headers)
      when :post
        response = connection.post(@url, @body, http_headers)
      when :delete
        response = connection.delete(@url, http_headers)
      else
        raise InvalidRequestException.new("Invalid method #{http_method}")
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
      if response.respond_to?(:proxied) && response.proxied
        ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Response was proxied, unable to determine size"
      else
        ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Response received #{response.body.size} bytes"
      end

      if @method[:options][:plain]
        return @response = response.body
      end

      @response = response

      if response.body.is_a?(Array) || response.body.is_a?(Hash)
        body = response.body
      else
        body = MultiJson.load(response.body) || {}
      end
      body = begin
        @method[:name].nil? ? body : translator.send(@method[:name], body)
      rescue NoMethodError
        body
      end
      if body.is_a? Array
        result = ActiveRestClient::ResultIterator.new(response.status)
        body.each do |json_object|
          result << new_object(json_object, @overriden_name)
        end
      else
        result = new_object(body, @overriden_name)
        result._status = response.status
        unless object_is_class?
          @object._copy_from(result)
          result = @object
        end
      end

      response.status ||= 200
      if response.status == 401
        raise HTTPUnauthorisedClientException.new(status:response.status, result:result, url:@url)
      elsif response.status == 403
        raise HTTPForbiddenClientException.new(status:response.status, result:result, url:@url)
      elsif response.status == 404
        raise HTTPNotFoundClientException.new(status:response.status, result:result, url:@url)
      elsif (400..499).include? response.status
        raise HTTPClientException.new(status:response.status, result:result, url:@url)
      elsif (500..599).include? response.status
        raise HTTPServerException.new(status:response.status, result:result, url:@url)
      end

      result
    rescue MultiJson::ParseError
      raise ResponseParseException.new(status:response.status, body:response.body)
    end

    def new_object(attributes, name = nil)
      @method[:options][:has_many] ||= {}
      name = name.to_sym rescue nil
      if @method[:options][:has_many][name]
        overriden_name = name
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
          object._attributes[k] = ActiveRestClient::LazyAssociationLoader.new(overriden_name || k, v, self, overriden_name:(overriden_name||k))
        elsif v.is_a? Hash
          object._attributes[k] = new_object(v, overriden_name || k)
        elsif v.is_a? Array
          object._attributes[k] = ActiveRestClient::ResultIterator.new
          v.each do |item|
            if item.is_a? Hash
              object._attributes[k] << new_object(item, overriden_name || k)
            else
              object._attributes[k] << item
            end
          end
        else
          if v.to_s[/\d{4}\-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})/]
            object._attributes[k] = DateTime.parse(v)
          else
            object._attributes[k] = v
          end
        end
      end
      object.clean! unless object_is_class?

      object
    end

    def hal_response?
      _, content_type = @response.headers.detect{|k,v| k.downcase == "content-type"}
      faked_response = @response.headers.detect{|k,v| k.downcase == "x-arc-faked-response"}
      if content_type && content_type.respond_to?(:each)
        content_type.each do |ct|
          return true if ct[%r{application\/hal\+json}i]
          return true if ct[%r{application\/json}i]
        end
        faked_response
      elsif content_type && (content_type[%r{application\/hal\+json}i] || content_type[%r{application\/json}i]) || faked_response
        true
      else
        false
      end
    end

    def handle_hal_links_embedded(object, attributes)
      attributes["_links"] = attributes[:_links] if attributes[:_links]
      attributes["_embedded"] = attributes[:_embedded] if attributes[:_embedded]
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

  class RequestException < StandardError ; end

  class InvalidRequestException < RequestException ; end
  class ResponseParseException < RequestException
    attr_accessor :status, :body
    def initialize(options)
      @status = options[:status]
      @body = options[:body]
    end
  end

  class HTTPException < RequestException
    attr_accessor :status, :result, :request_url
    def initialize(options)
      @status = options[:status]
      @result = options[:result]
      @request_url = options[:url]
    end
  end
  class HTTPClientException < HTTPException ; end
  class HTTPUnauthorisedClientException < HTTPClientException ; end
  class HTTPForbiddenClientException < HTTPClientException ; end
  class HTTPNotFoundClientException < HTTPClientException ; end
  class HTTPServerException < HTTPException ; end

end
