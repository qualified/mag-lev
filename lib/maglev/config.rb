module MagLev
  class Config

    attr_reader :adapter

    # set to a model name/class to enable current user functionality. Typically
    # you would set this to User (or 'User')
    attr_accessor :current_user_class

    # set to a statsd client instance if you wish to enable metrics tracking throughout the MagLev codebase
    attr_accessor :statsd

    def listeners_enabled?
      !!listeners.enabled
    end

    def sidekiq
      @sidekiq ||= Sidekiq.new.tap do |sidekiq|
        yield sidekiq if block_given?
      end
    end

    def listeners
      @listeners ||= Listeners.new.tap do |listeners|
        yield listeners if block_given?
      end
    end

    protected

    def apply
      sidekiq.send(:apply)
      listeners.send(:apply)

      apply_current_user
      @applied = true
    end

    def apply_current_user
      # convert the current_user_class to an actual class if it isnt one already
      if current_user_class.is_a?(String) or current_user_class.is_a?(Symbol)
        self.current_user_class = Object.const_get(current_user_class.to_s)
      end

      # automatically include the current user concern into the user class
      # TODO: figure out why this isnt working with rspec (probably a spring issue)
      if current_user_class
        current_user_class.include MagLev::CurrentUser
      end
    end

    class Sidekiq
      # change to false to disable sidekiq integration
      attr_accessor :enabled

      attr_accessor :unique_jobs_enabled

      # determines if additional serialization should be performed to handle more complex types
      # than sidekiq normally allows. Default is true
      attr_accessor :yaml_enabled

      # set if global_id should be enabled for sidekiq. By doing so, ORM records will be
      # serialized based off of their ID and then a fresh copy will be retrived once the job
      # executes. Default is true
      attr_accessor :global_id_enabled

      # set to a proc if you wish hook into to any error that is thrown while trying to locate a global id
      attr_accessor :global_id_error_handler

      attr_accessor :global_id_locator

      attr_accessor :heartbeat_interval
      # the amount of time that may pass between heartbeats before the process will exit itself. default = 30.
      # You can set to nil if you wish to never restart a process
      attr_accessor :max_heartbeat_interval

      def initialize
        @enabled = true
        @unique_jobs_enabled = true
        @global_id_enabled = true
        @yaml_enabled = true
        @global_id_locator = nil
        @process_limits = {}
        @heartbeat_interval = 5
        @max_heartbeat_interval = 30
      end

      # true if the any of the serialization features are enabled
      def serialize?
        yaml_enabled || global_id_enabled
      end

      protected

      def apply
        if enabled && !@applied
          config_global_id if global_id_enabled

          ::Sidekiq.configure_server do |config|
            config.server_middleware do |chain|
              add_default_server_middleware(chain)
            end

            if MagLev.config.statsd
              MagLev::Sidekiq::Statsd::Heartbeat.start
            end
          end

          if defined?(::Sidekiq::Testing)
            ::Sidekiq::Testing.server_middleware do |chain|
              add_default_server_middleware(chain)
            end
          end

          # configure client middleware for both client and server
          ::Sidekiq.client_middleware do |chain|
            chain.add MagLev::Sidekiq::UniqueJobs::Client if unique_jobs_enabled
            chain.add MagLev::Sidekiq::CurrentUser::Client if MagLev.config.current_user_class
            chain.add MagLev::Sidekiq::Serialization::Client if serialize?
            chain.add MagLev::Sidekiq::Listeners::Client
            chain.add MagLev::Sidekiq::Statsd::Client
          end

          @applied = true
        end
      end

      def config_global_id
        if global_id_locator
          GlobalID::Locator.use :sidekiq do |gid|
            begin
              global_id_locator.new(gid).locate
            rescue => ex
              global_id_error_handler.call(gid, ex) if global_id_error_handler
              raise
            end
          end
        end
      end

      def add_default_server_middleware(chain)
        chain.add MagLev::Sidekiq::Reliable::Server if defined?(::Mongoid::Document)
        chain.add MagLev::Sidekiq::Statsd::Server if MagLev.config.statsd
        chain.add MagLev::Sidekiq::Errors::Server
        chain.add MagLev::Sidekiq::Store::Server
        chain.add MagLev::Sidekiq::UniqueJobs::Server if unique_jobs_enabled
        chain.add MagLev::Sidekiq::Listeners::Server
        chain.add MagLev::Sidekiq::CurrentUser::Server if MagLev.config.current_user_class
        chain.add MagLev::Sidekiq::Serialization::Server if serialize?
        chain.add MagLev::Sidekiq::Timeout::Server
        chain.add MagLev::Sidekiq::SlowReporter::Server
      end
    end

    class Listeners

      # change to false to disable listener support
      attr_accessor :enabled

      # registers listeners so that they are known. You should always set the registration as a
      # String or Symbol, not a class, so that class reloaders such as Spring do not cause any issues during
      # development and testing
      attr_accessor :registrations

      # dispatch mode can be :all or :specified. When all is set then all active listeners
      # will be dispatched to for all events, when :specified is set then the dispatch method must
      # specifically specify which listeners should be dispatched to. Choose :specified when you want to
      # enforce deliberate ties to listeners, so that its easier to track the event structure from both
      # places in the code (the listener and the event broadcaster).
      attr_accessor :broadcast_mode

      # by default registrations are ignored within the test environment and must be explitly enabled
      # within each test. To disable this special behavior, set this value to false.
      attr_accessor :test_mode

      # by default appending _async to a listener method will cause the method to be called in the background.
      # you can set this to false to disable this behavior. NOTE: this behavior does not work correctly if you
      # have disabled Sidekiq yaml serialization
      attr_accessor :async_listeners

      def initialize
        @enabled = true
        @registrations = []
        @broadcast_mode = :specified
        @async_listeners = true
        @test_mode = true
      end

      # returns the configured groups relevant for the current running process
      def process_registrations
        MagLev.test? && test_mode ? [] : registration_classes
      end

      def registration_classes
        registrations.map {|r| Object.const_get(r) }
      end

      protected

      def apply
        registrations.compact!
      end
    end
  end
end