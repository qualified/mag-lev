module MagLev
  class ConfigurationError < RuntimeError
  end

  class EventError < RuntimeError
    attr_reader :event

    def initialize(msg = nil, event = nil)
      @event = event
      super(msg)
    end
  end

  class ResourceNotFoundError < RuntimeError
    attr_reader :gid

    def initialize(gid)
      @gid = gid
      msg = "Resource #{gid.model_class} could not be found with ID #{gid.model_id}"
      if gid.params
        msg += ": Params = #{gid.params}"
      end
      super(msg)
    end
  end

  # a generic error for indicating invalid data, that is handled outside of the model validation layer
  class InvalidDataError < RuntimeError
  end

  # error indicates that data is in an invalid state for the operation
  class InvalidStateError < RuntimeError

  end

  class DuplicationError < RuntimeError

  end

  class MissingDataError < ActionController::ParameterMissing

  end
end