module MagLev
  module Broadcastable
    def broadcast(event_name, *args)
      event = MagLev::Event.new(event_name, self, *args)
      if MagLev.config.listeners.broadcast_mode == :specified
        BroadcastProxy.new(event)
      else
        MagLev.broadcaster.broadcast(event)
      end
    end
  end

  class BroadcastProxy
    def initialize(event)
      @event = event
    end

    def to(*targets)
      MagLev.broadcaster.broadcast(@event.target(*targets))
    end

    # allows you to bypass needing to force to targets, useful for when you have a
    # dynamic/data driven event
    def to_all
      MagLev.broadcaster.broadcast(@event, force_targets: false)
    end

    def to_spies
      MagLev.broadcaster.broadcast(@event, spies_only: true)
    end
  end
end