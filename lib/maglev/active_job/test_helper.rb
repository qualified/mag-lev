module MagLev
  module ActiveJob
    # provides helper methods for testing
    # TODO: right now after_perform only works correctly because we are always including
    # this module even if test mode is not enabled. Ideally the rspec config would dynamically
    # include this module so that the code only loads within the test environment
    module TestHelper
      extend ActiveSupport::Concern

      included do
        after_enqueue do
          if MagLev.config.active_job.test_mode
            self.class.enqueued_jobs << self unless respond_to?(:skipped) && skipped?
          end
        end

        after_perform do
          if MagLev.config.active_job.test_mode
            self.class.performed_jobs << self
          end
        end
      end

      module ClassMethods
        def enqueued_jobs
          ActiveJob.enqueued_jobs[self.name] ||= []
        end

        def performed_jobs
          ActiveJob.performed_jobs[self.name] ||= []
        end
      end
    end

    def self.enqueued_jobs
      @enqueued_jobs ||= {}
    end

    def self.performed_jobs
      @performed_jobs ||= {}
    end
  end
end

# MagLev::ActiveJob::Base.include(MagLev::ActiveJob::TestHelper)