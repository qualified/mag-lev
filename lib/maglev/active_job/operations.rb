module MagLev
  module ActiveJob
    # Drains the operations queue at the end of the job lifecycle. Listeners are turned off during this
    # periods
    module Operations
      extend ActiveSupport::Concern

      included do
        around_perform do |_, block|
          # only drain if we are the entry/initiating job and this is not a web process.
          # In web environments, we consider the web request the lifecycle point for draining, not jobs,
          # but in Sidekiq, we consider each job (but not child jobs) the lifecycle point
          should_drain = !MagLev.web? && !MagLev.request_store[:entry_job]
          MagLev.request_store[:entry_job] ||= self
          block.call
          if should_drain
            MagLev.operations_queue.suspend_listeners_and_drain
          end
        end
      end
    end
  end
end