module MagLev
  # Queues a set of operations to be drained at a later time. The goal here is to queue possibly duplicate
  # operations that should be executed after other logic has completed, such as at the end of a request or
  # job lifecycle.
  class OperationsQueue
    def initialize
      @operations = {}
    end

    def values
      @operations.values
    end

    # Pushes a new operation. Key is used to de-dup operation requests
    # @param priority should be an integer, lower priority is ran first. If an operation was previously keyed at a lower
    #   priority, the higher priority will be stored
    # @param key should be a unique key for the operation.
    # @param block should be the operation to be performed
    def push(priority, key, &block)
      MagLev::Guard.type('priority', priority, Integer)
      MagLev::Guard.type('key', key, String)
      if !@operations[key] || @operations[key][0] < priority
        @operations[key] = [priority, block]
      end
    end

    # drains all operations. All operations will be ran, even if an error is raised by one of proceeding operations.
    def drain
      begin
        grouped = @operations.group_by {|_, val| val.first }
        grouped.keys.sort.each do |priority|
          group = grouped[priority]
          MagLev.logger.info "Draining queue priority #{priority} containing #{group.size} operations..."
          MagLev::Try.new(group).each do |key, block|
            MagLev.logger.info "Performing operation \"#{key}\""
            block.last.call
          end
        end
      ensure
        @operations = {}
      end
    end

    # convenience method for draining operations at the end of a lifecycle
    def suspend_listeners_and_drain
      MagLev.broadcaster.suspend { drain }
    end
  end
end
