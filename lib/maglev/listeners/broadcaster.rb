require 'maglev/active_job/async_job'

module MagLev
  def self.broadcaster
    Broadcaster.instance
  end

  class Broadcaster
    include MagLev::ClassLogger

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

    # true if the default listeners are currently being used
    def default_listeners?
      default_listeners == listener_names.to_a
    end

    def default_listeners
      @default_listeners ||= MagLev.config.listeners.registrations.map(&:to_s)
    end

    def listener_names
      @listener_names ||= Set.new(default_listeners)
    end

    def listener_classes
      listener_names.map do | listener |
        Object.const_get(listener)
      end
    end

    def listener_instances
      map_to_listener_instances(listener_classes)
    end

    def listen(*listeners)
      listener_names = listeners.map(&:to_s) - self.listener_names.to_a
      self.listener_names.merge(listener_names)

      # if a block is given we will only listen until the block is called
      if block_given?
        begin
          yield
        ensure
          self.listener_names.subtract(listener_names)
        end
      end
    end

    # more semantic version of only that doesn't take arguments, useful
    # for when you want to suspend everything temporarily
    def suspend
      only do
        yield
      end
    end

    # will execute the block provided with only the listeners given
    def only(*listeners)
      previous = @listener_names
      @listener_names = Set.new
      listen(*listeners)
      begin
        yield
      ensure
        @listener_names = previous
      end
    end

    # ignores the given listeners. If a block is provided (recommended) then it will only
    # ignore the listenres for the duration of the block execution.
    def ignore(*listeners)
      listener_names = listeners.map(&:to_s) & self.listener_names.to_a
      self.listener_names.subtract(listener_names)

      # if a block is given we will only listen until the block is called
      if block_given?
        begin
          yield
        ensure
          self.listener_names.merge(listener_names)
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
      unless enabled?
        MagLev.logger.info "Broadcaster is disabled, skipping #{event} broadcast"
        return
      end

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
      listener_instances.each do | listener |
        if event.targets.empty? or event.targets.include?(listener.class)
          listened = false

          # check for method, both with and without the bang method
          event_name = if listener.respond_to?(event.name, true)
            event.name.to_s
          elsif listener.respond_to?("#{event.name}!", true)
            "#{event.name}!"
          end

          if event_name
            begin
              listener.send(event_name, *event.args)

            rescue => ex
              event.errors << ex

              # if the bang method is used, then rethrow the error as it means we intend to halt the listener chain
              if !MagLev.config.listeners.rescue_listeners || event_name.end_with?('!')
                raise ex
              else
                logger.report(:error, ex)
              end
            ensure
              listened = true
              event.listened << listener.class.name
            end

            # if the event is marked as completed then break out of the loop
            break if event.completed?
          end

          if MagLev.config.listeners.async_listeners
            async_method = "#{event.name}_async"
            if listener.respond_to?(async_method, true)
              MagLev::ActiveJob::AsyncJob.perform_later(listener.class.name, async_method, *event.args)
              MagLev.logger.info "#{listener.class.name}.#{async_method} queued for background execution"
              event.listened << listener.class.name unless listened
              listened = true
            end
          end

          if !listened and event.targets.any?
            error = "event target was specified for #{listener.class.name} that does not support the #{event.name} event"
            if MagLev.production?
              logger.report(:warn, error)
            else
              raise EventError.new error
            end
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