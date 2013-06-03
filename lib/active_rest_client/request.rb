require "cgi"

module ActiveRestClient

  class Request
    attr_accessor :post_params, :get_params, :url

    def initialize(method, object, params = {})
      @method = method
      @object = object
      @params = params
    end

    def call
      connection = @object.get_connection rescue @object.class.get_connection
      prepare_params
      prepare_url
      if @object.respond_to? :_filter_request
        @object.send(:_filter_request, @method[:name], self)
      end
      append_get_parameters
      prepare_request_body
      case @method[:method]
      when :get
        connection.get(@url)
      when :put
        connection.put(@url, @request_body)
      when :post
        connection.post(@url, @request_body)
      when :delete
        connection.delete(@url, @request_body)
      end
    end

    def prepare_params
      params = @object.attributes rescue @params
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
  end

end
