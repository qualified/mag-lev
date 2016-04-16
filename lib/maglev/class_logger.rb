module MagLev
  module ClassLogger
    def logger
      @logger ||= ClassLogger::Logger.new(self)
    end

    def logger_name
      if respond_to? :name
        name
      else
        ''
      end
    end

    protected

    # easy way to log the return value of code
    def log_info(result = nil)
      result ||= yield
      logger.debug "#{caller_locations(1,1)[0].label}: #{result.inspect}"
      result
    end

    # easy way to log the return value of code
    def log_info(result = nil)
      result ||= yield
      logger.info "#{caller_locations(1,1)[0].label}: #{result.inspect}"
      result
    end

    class Logger
      def initialize(instance)
        @instance = instance
      end

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method level do |*args, &block|
          log(level, *args, &block)
        end
      end

      if defined?(Rails) and Rails.respond_to?(:logger)
        def log(level, *args, &block)
          if block_given?
            Rails.logger.send level do
              format(block.call)
            end
          else
            Rails.logger.send level, format(*args)
          end
        end
      else
        def log(method, *args, &block)
          if block_given?
            puts format(block.call)
          else
            puts format(*args)
          end
        end
      end

      def id
        if @instance.respond_to? :id
          "[#{@instance.id}] - "
        end
      end

      def format(msg, *args)
        msg = "#{@instance.class.name} #{id}#{@instance.logger_name}: #{msg}"
        [msg, *args].map(&:to_s).join(' | ')
      end

      def report(type, *args)
        args = args.compact
        if respond_to?(type)
          send(type, *args)
        end

        hash = args.find {|a| a.is_a? Hash}
        args << hash = {} unless hash
        hash[:logger_name] = @instance.logger_name
        hash[@instance.to_s] = @instance
        EventReporter.send(type, *args)
      end
    end
  end
end