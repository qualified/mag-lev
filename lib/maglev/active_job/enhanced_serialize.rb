
module MagLev
  module ActiveJob
    # this class replaces the default ActiveJob serialization with an enhanced strategy which
    # will handle serializing deleted models and utilizing YAML to serialize the rest.
    module EnhancedSerialize
      extend ActiveSupport::Concern

      included do
        # if set to false, MagLev will use the default ActiveJob serialization instead of its own
        extended_option :enhanced_serialize
      end

      # true if the job was serialized out of process.
      def serialized?
        !!defined?(@serialized_arguments)
      end

      protected

      def serialize_arguments(arguments)
        if extended_options['enhanced_serialize']
          Arguments.serialize(arguments)
        else
          ::ActiveJob::Arguments.serialize(arguments)
        end
      end

      def deserialize_arguments(serialized_args)
        if extended_options['enhanced_serialize']
          Arguments.deserialize(serialized_args)
        else
          ::ActiveJob::Arguments.deserialize(serialized_args)
        end
      end

      module Arguments
        TYPE_KEY = '_aj_type'.freeze
        SYMBOL_KEYS_KEY = '_aj_symbol_keys'.freeze
        RUBY2_KEYWORDS_KEY = "_aj_ruby2_keywords".freeze
        WITH_INDIFFERENT_ACCESS_KEY = '_aj_indifferent_access'.freeze

        class << self
          def serialize(arguments)
            arguments.map { |arg| serialize_argument(arg) }
          end

          def deserialize(arguments)
            arguments.map { |arg| deserialize_argument(arg) }
          end

          def serialize_argument(argument)
            begin
              case argument
                when NilClass, String, Integer, Float, BigDecimal, TrueClass, FalseClass
                  argument
                when Array
                  argument.map { |arg| serialize_argument(arg) }
                when ActiveSupport::HashWithIndifferentAccess
                  serialize_indifferent_hash(argument)
                when Hash
                  symbol_keys = argument.each_key.grep(Symbol).map!(&:to_s)
                  aj_hash_key = if Hash.ruby2_keywords_hash?(argument)
                                  RUBY2_KEYWORDS_KEY
                                else
                                  SYMBOL_KEYS_KEY
                                end
                  result = serialize_hash(argument)
                  result[aj_hash_key] = symbol_keys
                  result
                when Symbol
                  serialize_symbol(argument)
                when -> (arg) { arg.respond_to?(:permitted?) }
                  serialize_indifferent_hash(argument.to_h)
                else
                  if argument.respond_to?(:to_global_id)
                    if argument.respond_to?(:destroyed?) and argument.destroyed?
                      serialize_destroyed(argument)
                    else
                      serialize_global_id(argument)
                    end
                  else
                    serialize_yaml(argument)
                  end
              end
            rescue
              MagLev.logger.error("Unable to serialize #{argument}")
              raise
            end
          end

          RESERVED_KEYS = [
            TYPE_KEY, TYPE_KEY.to_sym,
            SYMBOL_KEYS_KEY, SYMBOL_KEYS_KEY.to_sym,
            RUBY2_KEYWORDS_KEY, RUBY2_KEYWORDS_KEY.to_sym,
            WITH_INDIFFERENT_ACCESS_KEY, WITH_INDIFFERENT_ACCESS_KEY.to_sym
          ]

          def serialize_hash(argument)
            argument.each_with_object({}) do |(key, value), hash|
              hash[serialize_hash_key(key)] = serialize_argument(value)
            end
          end

          def serialize_indifferent_hash(indifferent_hash)
            result = serialize_hash(indifferent_hash)
            result[WITH_INDIFFERENT_ACCESS_KEY] = true
            result
          end

          def deserialize_hash(argument)
            result = argument.transform_values { |v| deserialize_argument(v) }
            if result.delete(WITH_INDIFFERENT_ACCESS_KEY)
              result.with_indifferent_access
            elsif symbol_keys = result.delete(SYMBOL_KEYS_KEY)
              transform_symbol_keys(result, symbol_keys)
            elsif symbol_keys = result.delete(RUBY2_KEYWORDS_KEY)
              result = transform_symbol_keys(result, symbol_keys)
              Hash.ruby2_keywords_hash(result)
            else
              result
            end
          end

          def serialize_hash_key(key)
            case key
              when *RESERVED_KEYS
                raise ::ActiveJob::SerializationError.new("Cannot serialize a Hash with resorved key #{key.inspect}")
              when String, Symbol
                key.to_s
              else
                raise SerializationError.new("Only string and symbol hash keys may be serialized as job arguments, but #{key.inspect} is a #{key.class}")
            end
          end

          def transform_symbol_keys(hash, symbol_keys)
            hash.transform_keys do |key|
              if symbol_keys.include?(key)
                key.to_sym
              else
                key
              end
            end
          end

          def serialize_symbol(arg)
            {TYPE_KEY => 'symbol', 'value' => arg.to_s }
          end

          def serialize_destroyed(arg)
            {TYPE_KEY => 'destroyed', 'value' => arg.attributes.to_json, 'class' => arg.class.name }
          end

          def serialize_global_id(arg)
            app = GlobalID.app || 'maglev'
            {TYPE_KEY => 'gid', 'value' => arg.to_global_id(app: app).to_s}
          end

          def serialize_yaml(arg)
            yml = YAML.dump(arg)
            # remove Procs, as that will break something for sure
            yml = yml.lines.reject {|l| l.include?('!ruby/object:Proc') }.join('')
            {TYPE_KEY => 'yaml', 'value' => yml, 'id' => arg.to_s }
          end

          def deserialize_argument(argument)
            case argument
              when Array
                argument.map { |arg| deserialize_argument(arg) }
              when Hash
                case argument[TYPE_KEY]
                  when 'symbol'
                    argument['value'].to_sym
                  when 'gid'
                    ::GlobalID::Locator.locate(argument['value'])
                  when 'yaml'
                    YAML.load(argument['value'])
                  when 'destroyed'
                    deserialize_destroyed(argument)
                  else
                    deserialize_hash(argument)
                end
              else
                argument
            end
          end

          # special loader for loading destroyed models
          def deserialize_destroyed(arg)
            klass = arg['class'].constantize
            attributes = JSON.load(arg['value'])

            # if the class has its own load method
            if klass.respond_to?(:deserialize_destroyed)
              klass.load_destroyed(attributes)
              # otherwise use a basic implementation
            else
              klass.new(attributes).tap do |instance|
                instance.instance_variable_set('@destroyed', true)
              end
            end
          end
        end
      end
    end
  end
end