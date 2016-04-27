module MagLev
  module ActiveJob
    module ExtendedOptions
      def extended_options
        if @extended_options.nil?
          @extended_options = HashWithIndifferentAccess.new
          self.class.extended_options.each do |key, value|
            @extended_options[key] ||= value.is_a?(Proc) ? instance_exec(self, &value) : value
          end
        end

        @extended_options
      end

      # helper method for allowing an option to be configured as either a boolean or a hash,
      # with a block option will is used to provide the defaults
      def extended_option_config(name, default = {}, &block)
        config = extended_options[name.to_s] || {}
        defaults = block ? block.call : default

        case config
          when true
            defaults
          when false
            nil
          when Hash
            defaults.merge(config)
          else
            config
        end
      end

      def enqueue(options = {})
        options.each do |key, value|
          if extended_options.key?(key)
            extended_options[key] = value
          end
        end
        super
      end

      def serialize
        super.merge(extended_options.compact)
      end

      def deserialize(job_data)
        super
        @extended_options = {}
        self.class.extended_options.keys.each do |key|
          @extended_options[key] = job_data[key]
        end
      end

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def extended_options
          @extended_options ||= HashWithIndifferentAccess.new
        end

        def inherited(subclass)
          subclass.instance_variable_set("@extended_options", extended_options.dup)
        end

        # creates a new job option. Creates both a class level utility method plus instance methods.
        # the instance method can be overridden
        def extended_option(name, default = nil, internal: false, &block)
          extended_options[name.to_s] = block || default || Proc.new { MagLev.config.active_job.default_options[name] }

          unless internal
            define_singleton_method(name) do |value = nil, &block|
              # if a block is provided use that, otherwise use the set value, otherwise use the fallback or default value
              extended_options[name.to_s] = block || value
            end
          end
        end
      end
    end
  end
end