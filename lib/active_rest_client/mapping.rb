module ActiveRestClient
  module Mapping
    module ClassMethods
      def get(name, url, options = {})
        _map_call(name, url:url, method: :get, options:options)
      end

      def put(name, url, options = {})
        _map_call(name, url:url, method: :put, options:options)
      end

      def post(name, url, options = {})
        _map_call(name, url:url, method: :post, options:options)
      end

      def delete(name, url, options = {})
        _map_call(name, url:url, method: :delete, options:options)
      end

      def patch(name, url, options = {})
        _map_call(name, url:url, method: :patch, options:options)
      end

      def _map_call(name, details)
        _calls[name] = {name:name}.merge(details)
        _calls["lazy_#{name}".to_sym] = {name:name}.merge(details)
        self.class.send(:define_method, name) do |options={}|
          _call(name, options)
        end
        self.class.send(:define_method, "lazy_#{name}".to_sym) do |options={}|
          _call("lazy_#{name}", options)
        end
      end

      def _call(name, options)
        mapped = _calls[name]
        lazy_forced = false
        if mapped.nil? && name.to_s[/^lazy_/]
          mapped = _calls[name.to_s.gsub(/^lazy_/, '').to_sym]
          lazy_forced = true
        end
        request = Request.new(mapped, self, options)
        if lazy_load? || lazy_forced
          ActiveRestClient::LazyLoader.new(request)
        else
          request.call
        end
      end

      def _calls
        @_calls
      end

      def _mapped_method(name)
        _calls[name]
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@_calls, {})
      end

    end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
