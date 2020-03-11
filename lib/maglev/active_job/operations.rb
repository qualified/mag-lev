module MagLev
  module ActiveJob
    # Drains the operations queue at the end of the job lifecycle. Listeners are turned off during this
    # periods
    module Operations
      extend ActiveSupport::Concern

      included do
        after_perform { MagLev.operations_queue.suspend_listeners_and_drain }
      end
    end
  end
end