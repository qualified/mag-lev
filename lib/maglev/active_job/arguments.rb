module MagLev
  module ActiveJob
    module Arguments
      extend ActiveSupport::Concern

      included do
        define_callbacks :arguments
      end

      attr_reader :named_arguments

      def initialize(*arguments)
        super
        # NOTE that due to the way ActiveJob is designed, we are unable to support
        # fully optional arguments since we do wont be able to know if the object is being deserialized
        # or instantiated at this point. The perform method will make sure that fully optional
        # arguments get initialized but up to that point the arguments will not be handled.
        # As long as you pass at least 1 argument then initialization will be handled as expected.
        # This abnomality should only be an issue when used with the service object style pattern,
        # normal ActiveJob jobs rely on the perform method as the entry point anyway.
        initialize_arguments(*arguments) if arguments.any?
      end

      protected

      def deserialize_arguments_if_needed
        super
        initialize_arguments
      end

      # runs through all of the defined arguments and runs the processing function
      # for each, resulting in guards and defaults being applied.
      def initialize_arguments(*arguments)
        unless @arguments_initialized
          run_callbacks :arguments do
            @arguments_initialized = true
            arguments = self.arguments if arguments.empty?

            self.class.arguments.values.map.with_index do |config, ndx|
              self.arguments[ndx] = config.call(self, arguments[ndx])
            end

            if self.class.named_arguments.any?
              if arguments.count > self.class.arguments.count
                @named_arguments = arguments.last
              else
                self.arguments << @named_arguments = {}
              end

              self.class.named_arguments.each do |key, config|
                @named_arguments[key] = config.call(self, @named_arguments[key])
              end
            end
          end
        end
      end

      module ClassMethods

        def after_arguments(*filters, &blk)
          set_callback(:arguments, :after, *filters, &blk)
        end

        def arguments
          @arguments ||= defined?(superclass.arguments) ? superclass.arguments.dup : {}
        end

        def named_arguments
          @named_arguments ||= defined?(superclass.named_arguments) ? superclass.named_arguments.dup : {}
        end

        # defines an argument that is expected to be passed in to the job. You can configure type checking, guards and defaults.
        # An advantage of using this method over a standard initializer is that it will pull its value from the "arguments"
        # value instead of just using a separate instance variable. When combined with the optional setter method,
        # this is even futher useful by ensuring that anything you set will be properly enqueued.
        def argument(name, type: nil, guard: nil, default: nil, named: false, getter: true, setter: false, &block)
          ndx = arguments.count

          if getter
            define_method name do
              if named
                if arguments.count > self.class.arguments.count
                  arguments.last[name]
                end
              else
                arguments[ndx]
              end
            end
          end

          if setter
            define_method "#{name}=" do |value|
              if named
                if arguments.count > self.class.arguments.count
                  arguments.last[name] = value
                end
              else
                arguments[ndx] = value
              end
            end
          end

          # named values are stored in a nested hash. They should always be last
          store = named ? named_arguments : arguments
          store[name] = Proc.new do |job, value|
            # transform the value before running any guards on it
            value = if block
              job.instance_exec(value, &block)
            elsif value.nil?
              case default
                when Proc then default.call
                when Hash, Array then default.dup
                else default
              end
            else
              value
            end

            Guard.type(name, value, type, allow_nil: true) if type
            Guard.send(guard, name, value) if guard
            value
          end
        end
      end
    end
  end
end