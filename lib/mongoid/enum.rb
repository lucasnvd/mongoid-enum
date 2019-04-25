require "mongoid/enum/version"
require "mongoid/enum/validators/multiple_validator"
require "mongoid/enum/configuration"

module Mongoid
  module Enum
    extend ActiveSupport::Concern
    module ClassMethods

      def enum(name, values, options = {})
        field_name = :"#{Mongoid::Enum.configuration.field_name_prefix}#{name}"
        options    = default_options(values).merge(options)

        set_values_constant(name, values)
        create_field_and_index(field_name, options)

        create_validations(field_name, values, options)
        define_value_scopes_and_accessors(field_name, values, options)
        define_field_accessors(name, field_name, options)
      end

      private
      def default_options(values)
        {
          multiple: false,
          default:  values.first,
          required: true,
          validate: true
        }
      end

      def set_values_constant(name, values)
        const_set(name.to_s.upcase, values.map(&:to_s))
      end

      def create_field_and_index(field_name, options)
        field(field_name, default: options[:default], type: options[:multiple] && :array || :string)
        index({ field_name => 1 }, { background: 1, sparse: 1 })
      end

      def create_validations(field_name, values, options)
        if options[:validate]
          validator = (options[:multiple]) ? :'mongoid/enum/validators/multiple' : :inclusion
          validates(field_name, validator => { in: values.map(&:to_s), allow_nil: !options[:required] })
        end
      end

      def define_value_scopes_and_accessors(field_name, values, options)
        values.each do |value|
          scope value, -> do
            where(field_name => value)
          end
          
          options[:multiple] ? define_array_value_accessor(field_name, value) : define_string_value_accessor(field_name, value)
        end
      end

      def define_field_accessors(name, field_name, options)
        if options[:multiple]
          define_method("#{name}=") do |vals|
            self[field_name] = Array(vals).compact.map(&:to_s)
          end
        else
          define_method("#{name}=") do |val|
            self[field_name] = val.to_s
          end
        end
        
        define_method(name) do
          self[field_name]
        end
      end

      def define_array_value_accessor(field_name, value)
        define_method("#{value}?") do
          self[field_name].include?(value.to_s)
        end
        
        define_method("#{value}!") do
          update_attributes!(field_name => (self[field_name] || []) << value.to_s)
        end
      end

      def define_string_value_accessor(field_name, value)
        define_method("#{value}?") do
          self[field_name] == value.to_s
        end
        
        # Saving value as string instead of symbol. Symbols were deprecated in Mongo since version 2.8
        define_method("#{value}!") do
          update_attributes!(field_name => value.to_s)
        end
      end
    end
  end
end

#         if options[:multiple] && options[:validate]
#           validates field_name, :'mongoid/enum/validators/multiple' => { :in => values.map(&:to_sym), :allow_nil => !options[:required] }
#         FIXME: Shouldn't this be `elsif options[:validate]` ???
#         elsif validate
#           validates field_name, :inclusion => {:in => values.map(&:to_sym)}, :allow_nil => !options[:required]
#         end

#       def define_field_accessor(name, field_name, options)
#         return define_array_field_accessor(name, field_name) if options[:multiple]
#         define_string_field_accessor(name, field_name)
#       end

#       def define_array_field_accessor(name, field_name)
#         class_eval "def #{name}=(vals) self.write_attribute(:#{field_name}, Array(vals).compact.map(&:to_sym)) end"
#         class_eval "def #{name}() self.read_attribute(:#{field_name}) end"
#       end
