module MagLev
  module Rspec
    def self.default_options
      {
        active_job: {
          default_options: HashWithIndifferentAccess.new(
            enhanced_serialize: true,
            unique: false,
            current_user: false,
            timeout: nil,
            reliable: false,
            listeners: :inherit,
            slow_reporter: nil,
            retry_queue: 'retries',
            retry_limit: 0
          )
        }
      }
    end

    def self.configure(options = {})
      options = default_options.deep_merge(options)

      MagLev.config.active_job.test_mode = true

      # set the test version of the active_job default options
      MagLev.config.active_job.default_options = options.value_path('active_job.default_options')

      RSpec.configure do |config|
        config.around :each do |example|
          MagLev::Rspec.clear_state
          MagLev::Rspec.configure_listeners(example.metadata[:listeners]) do
            example.run
          end
        end

        # clean out the queue after each spec
        config.after(:each) do
          ActiveJob.enqueued_jobs.clear
          ActiveJob.performed_jobs.clear
          if ::ActiveJob::Base.queue_adapter.respond_to?(:enqueued_jobs)
            ::ActiveJob::Base.queue_adapter.enqueued_jobs = []
            ::ActiveJob::Base.queue_adapter.performed_jobs = []
          end
        end

        # setup helpers for specifying which active job queue adapter to use
        config.before :each do |example|
          adapter = example.metadata[:active_job] || MagLev.config.active_job.default_rspec_adapter_mode
          ::ActiveJob::Base.queue_adapter = MagLev::Rspec.aj_adapters[adapter]
        end
      end
    end

    def self.aj_adapters
      @aj_adapters ||= {
        test: ::ActiveJob::QueueAdapters::TestAdapter.new,
        inline: ::ActiveJob::QueueAdapters::TestAdapter.new.tap do |adapter|
          adapter.perform_enqueued_jobs = true
          adapter.perform_enqueued_at_jobs = true
        end
      }
    end

    # reset any shared state
    def self.clear_state
      RequestStore.store[:maglev] = nil
    end

    # support the ability to easily configure listener groups and instances on a per test basis
    def self.configure_listeners(listeners)
      # listeners are configured via registrations. For each test we want to remember the default
      # configuration, allow it to be minipulated and then eventually restored back to its original configuration.
      previous = MagLev.config.listeners.registrations
      if listeners
        # if listeners == true then we use the real configuration, otherwise we set registrations
        # to those provided
        MagLev.config.listeners.registrations = *listeners unless listeners == true
      else
        # by default we assume no listeners are configured
        MagLev.config.listeners.registrations = []
      end

      begin
        yield
      ensure
        MagLev.config.listeners.registrations = previous
      end
    end
  end
end