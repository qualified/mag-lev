module MagLev
  def self.broadcaster
    Broadcaster.instance
  end

  class Broadcaster
    class << self
      def instance
        MagLev.request_store[:broadcaster] ||= Broadcaster.new
      end
    end

    attr_reader :event

    def initialize
      @listener_mappings = {}
      @spies = []
    end

    def enabled?
      !@disabled && MagLev.config.listeners.enabled
    end

    def disable!
      @disabled = true
    end

    def enable!
      @disabled = false
    end

    # a simply way to register an instance class to listen to events.
    # this instance will listen to all events regardless if they are targetted or not
    def spy(instance)
      @spies << instance
      begin
        yield
      ensure
        @spies.delete(instance)
      end
    end

    def default_listeners
      @default_listeners ||= map_to_listener_instances(MagLev.config.listeners.process_registrations)
    end

    def listeners
      @listeners ||= Set.new(default_listeners)
    end

    def listen(*listeners)
      listeners = map_to_listener_instances(listeners) - self.listeners.to_a
      self.listeners.merge(listeners)

      # if a block is given we will only listen until the block is called
      if block_given?
        begin
          yield
        ensure
          self.listeners.subtract(listeners)
        end
      end
    end

    def ignore(*listeners)
      listeners = map_to_listener_instances(listeners) & self.listeners.to_a
      self.listeners.subtract(listeners)

      # if a block is given we will only listen until the block is called
      if block_given?
        begin
          yield
        ensure
          self.listeners.merge(listeners)
        end
      end
    end

    def listener_instance(listener)
      @listener_mappings[listener] ||= listener.is_a?(Class) ? listener.new : listener
    end

    def broadcasted
      @broadcasted ||= []
    end

    # broadcastes an event to listeners and spies.
    def broadcast(event, spies_only: false, force_targets: MagLev.config.listeners.broadcast_mode == :specified)
      return unless enabled?
      raise EventError.new("Event #{event.event_name} already broadcasted") if event.broadcasted?

      if event.targets.none? and force_targets
        raise ConfigurationError.new("broadcast_mode is set to specified but no event targets were given for #{event.name}")
      end

      MagLev::Statsd.perform('broadcasts', event.name) do
        with_event(event) do
          broadcast_listeners unless spies_only
          broadcast_spies
        end
      end

      # only track up to the most recent 1000 events
      broadcasted.shift if broadcasted.size >= 1000
      broadcasted << event

      event # return the event so that chaining can be used and to indicate success
    end

    protected

    def broadcast_listeners
      listeners.each do | listener |
        if event.targets.empty? or event.targets.include?(listener.class)
          listened = false

          if listener.respond_to?(event.name, true)
            listener.send(event.name, *event.args)
            event.listened << listener.class.name
            listened = true
            # if the event is marked as completed then break out of the loop
            break if event.completed?
          end

          if MagLev.config.listeners.async_listeners
            async_method = "#{event.name}_async"
            if listener.respond_to?(async_method, true)
              MagLev::Sidekiq::Listeners::Worker.perform_async(listener.class.name, async_method, *event.args)
              event.listened << listener.class.name unless listened
              listened = true
            end
          end

          if !listened and event.targets.any?
            raise EventError.new("event target was specified for #{listener.class.name} that does not support the #{event.name} event")
          end
        end
      end
    end

    def broadcast_spies
      # spies listen to any event they have a method for, regardless of the event
      # being completed or not targetted towards them
      @spies.each do |spy|
        if spy.respond_to?(event.name, true)
          spy.send(event.name, *event.args)
          event.listened << spy.class.name
        end
      end
    end

    def with_event(event)
      old_event = @event
      event.parent = @event if @event
      begin
        event.mark_broadcasted
        @event = event
        yield
      ensure
        event.complete
        @event = old_event
      end
    end

    # support Singletons, Classes and instances
    def map_to_listener_instances(array)
      array.map { |listener| listener_instance(listener) }
    end
  end
end