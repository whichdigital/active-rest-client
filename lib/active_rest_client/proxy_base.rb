require "uri"

module ActiveRestClient
  class ProxyBase
    cattr_accessor :mappings, :request, :original_handler
    cattr_accessor :original_body, :original_get_params, :original_post_params, :original_url

    module ClassMethods
      def get(match, &block)
        add_mapping(:get, match, block)
      end

      def post(match, &block)
        add_mapping(:post, match, block)
      end

      def put(match, &block)
        add_mapping(:put, match, block)
      end

      def delete(match, &block)
        add_mapping(:delete, match, block)
      end

      def add_mapping(method_type, match, block)
        @mappings ||= []

        if match.is_a?(String) && (param_keys = match.scan(/:\w+/)) && param_keys.any?
          param_keys.each do |key|
            match.gsub!(key, "([^/]+)")
          end
          param_keys = param_keys.map {|k| k.gsub(":", "").to_sym}
          match = Regexp.new(match)
        end

        @mappings << OpenStruct.new(http_method:method_type, match:match, block:block, param_keys:param_keys)
      end

      def body(value = nil)
        @body = value if value
        @body
      end

      def url(value = nil)
        @url = value if value
        @url
      end

      def get_params(value = nil)
        @get_params = value if value
        @get_params
      end

      def post_params(value = nil)
        @post_params = value if value
        @post_params
      end

      def params(value = nil)
        @params = value if value
        @params
      end

      def passthrough
        rebuild_request
        @original_handler.call(@request)
      end

      def translate(result, options = {})
        result.headers["content-type"] = "application/hal+json"
        result = OpenStruct.new(status:result.status, headers:result.headers, body:result.body)
        obj = MultiJson.load(result.body)
        result.body = yield obj
        result
      end

      def rebuild_request
        if @url != @original_url
          @request.forced_url = @request.url = @url
        end
        if @body != @original_body
          @request.body = @body
        elsif @post_params != @original_post_params
          @request.body = nil
          @request.prepare_request_body(@post_params)
        end
        if @get_params != @original_get_params
          @request.get_params = @get_params
          @request.prepare_url
          @request.append_get_parameters
        end
      end

      def handle(request, &block)
        @request = request
        @original_handler = block

        @original_body = request.body
        @body = @original_body.dup

        @original_get_params = request.get_params
        @get_params = @original_get_params.dup

        @original_post_params = request.post_params
        @post_params = (@original_post_params || {}).dup

        @original_url = request.url
        @url = @original_url.dup

        if mapping = find_mapping_for_current_request
          self.class_eval(&mapping.block)
        else
          passthrough
        end
      end

      def find_mapping_for_current_request
        uri = URI.parse(@original_url)
        @mappings ||= []
        @params = {}
        @mappings.each do |mapping|
          match = mapping.match
          if (match_data = uri.path.match(match)) && @request.http_method.to_sym == mapping.http_method
            matches = match_data.to_a
            matches.shift
            matches.each_with_index do |value, index|
              @params[mapping.param_keys[index]] = value
            end
            return mapping
          end
        end
        nil
      end

      def render(body, status=200, content_type="application/javascript", headers={})
        headers["Content-type"] = content_type
        OpenStruct.new(body:body, status:status, headers:headers, proxied:true)
      end
    end

    def self.inherited(base)
      base.extend(ClassMethods)
    end
  end
end
