module ActionController
  class Parameters
    # called after a permit!, which then checks to ensure that certain keys
    # are included. If any are missing, an ActionController::ParameterMissing error
    # will be thrown.
    def enforce!(*keys)
      keys.each do |key|
        raise ActionController::ParameterMissing.new(key) if self[key].blank?
      end
      self
    end
  end
end
