module MagLev
  def self.config
    @config ||= MagLev::Config.new
  end

  def self.configure
    yield(config) if block_given?
    config.send(:apply)
  end

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
      @sidekiq ||= Sidekiq.new.tap do |config|
        yield config if block_given?
      end
    end

    def active_job
      @active_job ||= ActiveJob.new.tap do |config|
        yield config if block_given?
      end
    end

    def listeners
      @listeners ||= Listeners.new.tap do |config|
        yield config if block_given?
      end
    end

    protected

    def apply
      apply_current_user
      sidekiq.send(:apply)
      @applied = true
    end

    # TODO: using the "inherited" method this could probaby be automated
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
      attr_accessor :heartbeat_interval
      # the amount of time that may pass between heartbeats before the process will exit itself. default = 30.
      # You can set to nil if you wish to never restart a process
      attr_accessor :max_heartbeat_interval

      def initialize
        @heartbeat_interval = 5
        @max_heartbeat_interval = 30
      end

      def apply
        if defined?(::Sidekiq)
          ::Sidekiq.configure_server do |config|
            if MagLev.config.statsd
              MagLev::Integrations::Sidekiq::Heartbeat.start
            end
          end
        end
      end
    end

    class ActiveJob
      # the default extended option values
      attr_accessor :default_options

      # sets the default mode used when testing activejobs with rspec.
      attr_accessor :default_rspec_adapter_mode

      # when enabled special treatment is used within jobs so that they are treated as if
      # they are operating in separate processes when really everything is inline.
      attr_accessor :test_mode

      def initialize
        @default_options = HashWithIndifferentAccess.new(
          enhanced_serialize: false,
          unique: true,
          current_user: true,
          timeout: nil,
          reliable: false,
          listeners: true,
          slow_reporter: nil,
          retry_queue: 'retries',
          retry_limit: 10
        )

        @default_rspec_adapter_mode = :inline
      end

      # true if the any of the serialization features are enabled
      def serialize?
        yaml_enabled || global_id_enabled
      end
    end

    class Listeners

      # change to false to disable listener support
      attr_accessor :enabled

      # registers listeners so that they are known. You should always set the registration as a
      # String or Symbol, not a class, so that class reloaders such as Spring do not cause any issues during
      # development and testing
      attr_reader :registrations

      def registrations=(value)
        @registration_classes = nil
        @registrations = value.compact
      end

      # dispatch mode can be :all or :specified. When all is set then all active listeners
      # will be dispatched to for all events, when :specified is set then the dispatch method must
      # specifically specify which listeners should be dispatched to. Choose :specified when you want to
      # enforce deliberate ties to listeners, so that its easier to track the event structure from both
      # places in the code (the listener and the event broadcaster).
      attr_accessor :broadcast_mode

      # by default appending _async to a listener method will cause the method to be called in the background.
      # you can set this to false to disable this behavior. NOTE: this behavior does not work correctly if you
      # have disabled Sidekiq yaml serialization
      attr_accessor :async_listeners

      def initialize
        @enabled = true
        @registrations = []
        @broadcast_mode = :specified
        @async_listeners = true
      end

      def registration_classes
        @registration_classes ||= registrations.map do |r|
          r.is_a?(Class) ? r : Object.const_get(r)
        end
      end
    end
  end
end