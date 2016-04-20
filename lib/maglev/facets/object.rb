class Object
  # macro for ||= a instance variable. an optional reset flag can be provided to force a reevaluation of the value
  def instance_variable_fetch(name, reset = false)
    v = reset ? nil : instance_variable_get(name)
    if v == nil
      v = yield
      instance_variable_set(name, v) if v
    end
    v
  end

  # if the value is nil or empty then the default value will be used
  def if_nil_or_empty(default = nil)
    if nil? or (respond_to?(:empty?) and empty?)
      block_given? ? yield : default
    else
      self
    end
  end
end