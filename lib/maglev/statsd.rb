require 'concurrent'

module MagLev
  module Statsd
    def self.method_missing(*args, &block)
      statsd_call(*args, &block)
    end

    def self.enabled?
      if @enabled.nil?
        @enabled = !!defined?(StatsD)
      end
      @enabled
    end

    def self.statsd_call(*args, &block)
      if enabled? && StatsD.respond_to?(args.first)
        StatsD.send(*args, &block)
      else
        block.call if block
      end
    end

    # captures information such as count, time, success and failures. You can pass in a root and
    # a branch to capture 2 different levels of information. if you only pass in one key then
    # a root level will not be tracked.
    # example: perform("jobs", "my_worker") {}
    def self.perform(root, branch = nil, &block)
      return block.call if MagLev.test? or !self.client

      if branch
        branch = "#{root}.#{branch}"
      else
        branch = root
        root = nil
      end

      if enabled?
        begin
          StatsD.increment("#{root}.count") if root
          StatsD.increment("#{branch}.count")
          branch_perform = -> { StatsD.measure("#{branch}.perform", &block) }

          if root
            StatsD.measure("#{root}.perform") do
              branch_perform.call
            end
          else
            branch_perform.call
          end

          StatsD.increment("#{root}.success") if root
          StatsD.increment("#{branch}.success")
        rescue Exception
          StatsD.increment("#{root}.failure") if root
          StatsD.increment("#{branch}.failure")
          raise
        end
      else
        block.call
      end
    end
  end
end
