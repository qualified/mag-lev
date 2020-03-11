module MagLev
  module ActiveJob
    module Store
      extend ActiveSupport::Concern

      included do
        # handles whether or not we should use test mode for storing MagLev request store information.
        # In test mode, everything is running inline instead of multi-process, so we need to
        # treat the store as a fresh copy in order to simulate its normal state.
        # Test mode is only used if the job is serialized. Jobs that were not serialized
        # are considered to have never been enqueued and thus run in-process.
        # If not in test mode, we still need to ensure that state is reset if the job is serialized, since
        # that means this is a fresh entry point
        around_perform do |_, block|
          if serialized?
            if MagLev.config.active_job.test_mode
              previous = RequestStore.store[:maglev]
              begin
                RequestStore.store[:maglev] = nil
                block.call
              ensure
                RequestStore.store[:maglev] = previous
              end
            # if not test mode then no need to restore previous state, but we do need to make sure maglev has a fresh
            # state since this job is its own entry point (think of it like a web request)
            else
              RequestStore.store[:maglev] = nil
              block.call
            end
          else
            block.call
          end
        end
      end
    end
  end
end