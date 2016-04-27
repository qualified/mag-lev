module MagLev
  module ActiveJob
    module Store
      extend ActiveSupport::Concern

      included do
        # handles wether or not we should use test mode for storing MagLev request store information.
        # In test mode, everything is running inline instead of multi-process, so we need to
        # treat the store as a fresh copy in order to simulate its normal state.
        # Test mode is only used if the job is serialized. Jobs that were not serialized
        # are considered to have never been enqueued and thus run in-process.
        around_perform do |_, block|
          if MagLev.config.active_job.test_mode and serialized?
            previous = RequestStore.store[:maglev]
            begin
              RequestStore.store[:maglev] = nil
              block.call
            ensure
              RequestStore.store[:maglev] = previous
            end
          else
            block.call
          end
        end
      end
    end
  end
end