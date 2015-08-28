require "cgi"
require "multi_json"
require 'crack'
require 'crack/xml'

module ActiveRestClient

  class Request
    attr_accessor :post_params, :get_params, :url, :path, :headers, :method, :object, :body, :forced_url, :original_url

    def initialize(method, object, params = {})
      @method                     = method
      @method[:options]           ||= {}
      @method[:options][:lazy]    ||= []
      @method[:options][:has_one] ||= {}
      @overridden_name             = @method[:options][:overridden_name]
      @object                     = object
      @response_delegate          = ActiveRestClient::RequestDelegator.new(nil)
      @params                     = params
      @headers                    = HeadersList.new
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

    def using_api_auth?
      if object_is_class?
        @object.using_api_auth?
      else
        @object.class.using_api_auth?
      end
    end

    def api_auth_access_id
      if object_is_class?
        @object.api_auth_access_id
      else
        @object.class.api_auth_access_id
      end
    end

    def api_auth_secret_key
      if object_is_class?
        @object.api_auth_secret_key
      else
        @object.class.api_auth_secret_key
      end
    end

    def username
      if object_is_class?
        @object.username
      else
        @object.class.username
      end
    end

    def password
      if object_is_class?
        @object.password
      else
        @object.class.password
      end
    end

    def request_body_type
      if @method[:options][:request_body_type]
        @method[:options][:request_body_type]
      elsif object_is_class?
        @object.request_body_type
      else
        @object.class.request_body_type
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
        @explicit_parameters = explicit_parameters
        @body = nil
        prepare_params
        prepare_url
        if fake = @method[:options][:fake]
          if fake.respond_to?(:call)
            fake = fake.call(self)
          end
          ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Faked response found"
          content_type = @method[:options][:fake_content_type] || "application/json"
          return handle_response(OpenStruct.new(status:200, body:fake, response_headers:{"X-ARC-Faked-Response" => "true", "Content-Type" => content_type}))
        end
        if object_is_class?
          @object.send(:_filter_request, :before, @method[:name], self)
        else
          @object.class.send(:_filter_request, :before, @method[:name], self)
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

        response = (
          if proxy
            proxy.handle(self) do |request|
              request.do_request(etag)
            end
          else
            do_request(etag)
          end
        )

        # This block is called immediately when this request is not inside a parallel request block.
        # Otherwise this callback is called after the parallel request block ends.
        response.on_complete do |response_env|
          if verbose?
            ActiveRestClient::Logger.debug "  Response"
            ActiveRestClient::Logger.debug "  << Status : #{response_env.status}"
            response_env.response_headers.each do |k,v|
              ActiveRestClient::Logger.debug "  << #{k} : #{v}"
            end
            ActiveRestClient::Logger.debug "  << Body:\n#{response_env.body}"
          end

          if object_is_class? && @object.record_response?
            @object.record_response(self.url, response_env)
          end
          if object_is_class?
            @object.send(:_filter_request, :after, @method[:name], response_env)
          else
            @object.class.send(:_filter_request, :after, @method[:name], response_env)
          end

          result = handle_response(response_env, cached)
          @response_delegate.__setobj__(result)
          original_object_class.write_cached_response(self, response_env, result)
        end

        # If this was not a parallel request just return the original result
        return result if response.finished?
        # Otherwise return the delegate which will get set later once the call back is completed
        return @response_delegate
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
        @url += "?" + @get_params.to_query
      end
    end

    def prepare_request_body(params = nil)
      if request_body_type == :form_encoded
        @body ||= (params || @post_params || {}).to_query
        headers["Content-Type"] ||= "application/x-www-form-urlencoded"
      elsif request_body_type == :json
        @body ||= (params || @post_params || {}).to_json
        headers["Content-Type"] ||= "application/json; charset=utf-8"
      end
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
        @url = @method[:options][:url] || @method[:url]
        @url = @forced_url if @forced_url
        if connection = ActiveRestClient::ConnectionManager.find_connection_for_url(@url)
          @url = @url.slice(connection.base_url.length, 255)
        else
          parts = @url.match(%r{^(https?://[a-z\d\.:-]+?)(/.*)}).to_a
          if (parts.empty?) # Not a full URL, so use hostname/protocol from existing base_url
            uri = URI.parse(base_url)
            @base_url = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port != 80 && uri.port != 443}"
            @url = "#{base_url}#{@url}".gsub(@base_url, "")
          else
            _, @base_url, @url = parts
          end
          base_url.gsub!(%r{//(.)}, "//#{username}:#{password}@\\1") if username && !base_url[%r{//[^/]*:[^/]*@}]
          connection = ActiveRestClient::ConnectionManager.get_connection(@base_url)
        end
      else
        parts = @url.match(%r{^(https?://[a-z\d\.:-]+?)(/.*)}).to_a
        if (parts.empty?) # Not a full URL, so use hostname/protocol from existing base_url
          uri = URI.parse(base_url)
          @base_url = "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port != 80 && uri.port != 443}"
          @url = "#{base_url}#{@url}".gsub(@base_url, "")
          base_url = @base_url
        end
        base_url.gsub!(%r{//(.)}, "//#{username}:#{password}@\\1") if username && !base_url[%r{//[^/]*:[^/]*@}]
        connection = ActiveRestClient::ConnectionManager.get_connection(base_url)
      end
      ActiveRestClient::Logger.info "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Requesting #{connection.base_url}#{@url}"

      if verbose?
        ActiveRestClient::Logger.debug "ActiveRestClient Verbose Log:"
        ActiveRestClient::Logger.debug "  Request"
        ActiveRestClient::Logger.debug "  >> #{http_method.upcase} #{@url} HTTP/1.1"
        http_headers.each do |k,v|
          ActiveRestClient::Logger.debug "  >> #{k} : #{v}"
        end
        ActiveRestClient::Logger.debug "  >> Body:\n#{@body}"
      end

      request_options = {:headers => http_headers}
      if using_api_auth?
        request_options[:api_auth] = {
          :api_auth_access_id => api_auth_access_id,
          :api_auth_secret_key => api_auth_secret_key
        }
      end

      case http_method
      when :get
        response = connection.get(@url, request_options)
      when :put
        response = connection.put(@url, @body, request_options)
      when :post
        response = connection.post(@url, @body, request_options)
      when :delete
        response = connection.delete(@url, request_options)
      else
        raise InvalidRequestException.new("Invalid method #{http_method}")
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

    def handle_response(response, cached = nil)
      @response = response
      status = @response.status || 200

      if cached && response.status == 304
        ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name}" +
          ' - Etag copy is the same as the server'
        return handle_cached_response(cached)
      end

      if (200..399).include?(status)
        if @method[:options][:plain]
          return @response = response.body
        elsif is_json_response? || is_xml_response?
          if @response.respond_to?(:proxied) && @response.proxied
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Response was proxied, unable to determine size"
          else
            ActiveRestClient::Logger.debug "  \033[1;4;32m#{ActiveRestClient::NAME}\033[0m #{@instrumentation_name} - Response received #{@response.body.size} bytes"
          end
          result = generate_new_object(ignore_xml_root: @method[:options][:ignore_xml_root])
        else
          raise ResponseParseException.new(status:status, body:@response.body)
        end
      else
        if is_json_response? || is_xml_response?
          error_response = generate_new_object(mutable: false, ignore_xml_root: @method[:options][:ignore_xml_root])
        else
          error_response = @response.body
        end
        if status == 400
          raise HTTPBadRequestClientException.new(status:status, result:error_response, url:@url)
        elsif status == 401
          raise HTTPUnauthorisedClientException.new(status:status, result:error_response, url:@url)
        elsif status == 403
          raise HTTPForbiddenClientException.new(status:status, result:error_response, url:@url)
        elsif status == 404
          raise HTTPNotFoundClientException.new(status:status, result:error_response, url:@url)
        elsif (400..499).include? status
          raise HTTPClientException.new(status:status, result:error_response, url:@url)
        elsif (500..599).include? status
          raise HTTPServerException.new(status:status, result:error_response, url:@url)
        elsif status == 0
          raise TimeoutException.new("Timed out getting #{response.url}")
        end
      end

      result
    end

    def new_object(attributes, name = nil)
      @method[:options][:has_many] ||= {}
      name = name.to_sym rescue nil
      if @method[:options][:has_many][name]
        overridden_name = name
        object = @method[:options][:has_many][name].new
      elsif @method[:options][:has_one][name]
        overridden_name = name
        object = @method[:options][:has_one][name].new
      else
        object = create_object_instance
      end

      if hal_response? && name.nil?
        attributes = handle_hal_links_embedded(object, attributes)
      end

      attributes.each do |k,v|
        k = k.to_sym
        overridden_name = select_name(k, overridden_name)
        if @method[:options][:lazy].include?(k)
          object._attributes[k] = ActiveRestClient::LazyAssociationLoader.new(overridden_name, v, self, overridden_name:(overridden_name))
        elsif v.is_a? Hash
          object._attributes[k] = new_object(v, overridden_name )
        elsif v.is_a? Array
          object._attributes[k] = ActiveRestClient::ResultIterator.new
          v.each do |item|
            if item.is_a? Hash
              object._attributes[k] << new_object(item, overridden_name)
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
      _, content_type = @response.response_headers.detect{|k,v| k.downcase == "content-type"}
      faked_response = @response.response_headers.detect{|k,v| k.downcase == "x-arc-faked-response"}
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

    private

    def create_object_instance
      return object_is_class? ? @object.new : @object.class.new
    end

    def select_name(name, parent_name)
      if @method[:options][:has_many][name] || @method[:options][:has_one][name]
        return name
      end

      parent_name || name
    end

    def is_json_response?
      @response.response_headers['Content-Type'].nil? || @response.response_headers['Content-Type'].include?('json')
    end

    def is_xml_response?
      @response.response_headers['Content-Type'].include?('xml')
    end

    def generate_new_object(options={})
      if @response.body.is_a?(Array) || @response.body.is_a?(Hash)
        body = @response.body
      elsif is_json_response?
        body = @response.body.blank? ? {} : MultiJson.load(@response.body)
      elsif is_xml_response?
        body = @response.body.blank? ? {} : Crack::XML.parse(@response.body)
        if options[:ignore_xml_root]
          body = body[options[:ignore_xml_root].to_s]
        end
      end
      body = begin
        @method[:name].nil? ? body : translator.send(@method[:name], body)
      rescue NoMethodError
        body
      end
      if body.is_a? Array
        result = ActiveRestClient::ResultIterator.new(@response)
        body.each do |json_object|
          result << new_object(json_object, @overridden_name)
        end
      else
        result = new_object(body, @overridden_name)
        result._status = @response.status
        result._headers = @response.response_headers
        result._etag = @response.response_headers['ETag']
        if !object_is_class? && options[:mutable] != false
          @object._copy_from(result)
          @object._clean!
          result = @object
        end
      end
      result
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
  class HTTPBadRequestClientException < HTTPClientException ; end
  class HTTPForbiddenClientException < HTTPClientException ; end
  class HTTPNotFoundClientException < HTTPClientException ; end
  class HTTPServerException < HTTPException ; end

end
