module MagLev
  class Event
    attr_reader :name, :source, :args, :listened, :targets, :spies_only, :errors
    attr_accessor :parent

    def initialize(name, source, *args)
      Guard.nil('name', name)
      @name = name
      @source = source
      @args = args
      @targets = []
      @errors = []

      # this tracks the name of the listeners that were actually broadcasted to.
      @listened = []
    end

    # sets the targets that the event should be dispatched to. If
    def target(*targets)
      @targets = targets
      self
    end

    alias :to :target

    def broadcasted?
      @broadcasted
    end

    # Marks the event as completed. It is meant for internal usage to indicate that the event
    # is no longer running but could be used as a way to early return from an dispatch process
    # if needed.
    def complete
      @completed = true
    end

    def completed?
      !!@completed
    end

    def raise_if_errors
      raise MagLev::EventError.new('One or more errors raised within listener', self) if errors
    end

    # true if the event is currently being dispatched but has not completed yet
    def broadcasting?
      broadcasted? && !completed?
    end

    def mark_broadcasted
      @broadcasted = true
    end
  end
end