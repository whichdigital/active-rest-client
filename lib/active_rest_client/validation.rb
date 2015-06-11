module ActiveRestClient
  module Validation
    module ClassMethods
      def validates(field_name, options={}, &block)
        @_validations ||= []
        @_validations << {field_name:field_name, options:options, block:block}
      end

      def _validations
        @_validations ||= []
        @_validations
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def valid?
      @errors = Hash.new {|h,k| h[k] = []}
      self.class._validations.each do |validation|
        value = self.send(validation[:field_name])
        validation[:options].each do |type, options|
          if type == :presence
            if value.nil?
              @errors[validation[:field_name]] << "must be present"
            end
          elsif type == :length
            if options[:within]
              @errors[validation[:field_name]] << "must be within range #{options[:within]}" unless options[:within].include?(value.to_s.length )
            end
            if options[:minimum]
              @errors[validation[:field_name]] << "must be at least #{options[:minimum]} characters long" unless value.to_s.length >= options[:minimum]
            end
            if options[:maximum]
              @errors[validation[:field_name]] << "must be no more than #{options[:minimum]} characters long" unless value.to_s.length <= options[:maximum]
            end
          elsif type == :numericality
            numeric = (true if Float(value) rescue false)
            @errors[validation[:field_name]] << "must be numeric" unless numeric
          elsif type == :minimum && !value.nil?
            @errors[validation[:field_name]] << "must be at least #{options}" unless value.to_f >= options.to_f
          elsif type == :maximum && !value.nil?
            @errors[validation[:field_name]] << "must be no more than #{options}" unless value.to_f <= options.to_f
          end
        end
        if validation[:block]
          validation[:block].call(self, validation[:field_name], value)
        end
      end
      @errors.empty?
    end

    def _errors
      @errors ||= Hash.new {|h,k| h[k] = []}
      @errors
    end
  end

end
