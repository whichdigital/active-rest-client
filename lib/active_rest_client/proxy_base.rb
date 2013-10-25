module ActiveRestClient
  class ProxyBase

    cattr_accessor :mappings, :request, :original_handler
    cattr_accessor :original_body, :original_get_params, :original_post_params, :original_url

    self.mappings = []

    class << self
      %i{get post put delete}.each do |method_type|
        define_method(method_type) do |match, &block|
          self.mappings << OpenStruct.new(method:method_type, match:match, block:block)
        end
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

      def passthrough
        rebuild_request
        @original_handler.call(@request)
      end

      def translate(result)
        result = OpenStruct.new(status:result.status, headers:result.headers, body:result.body)
        obj = Oj.load(result.body)
        result.body = yield obj
        result
      end

      def rebuild_request
        if @url != @original_url
          @request.url = @url
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
        @post_params = @original_post_params.dup

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
        self.mappings.each do |mapping|
          if uri.path.match(mapping.match) #&& @request.http_method.to_sym == mapping.method
            return mapping
          end
        end
        nil
      end

      def render(body, status=200, content_type="application/javascript", headers={})
        headers["Content-type"] = content_type
        OpenStruct.new(body:body, status:status, headers:headers)
      end
    end
  end
end
