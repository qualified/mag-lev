class Hash
  # transforms the values provided using the block given. If no keys are specified all keys will be used.
  # This method is immutable (A new instance will be returned).
  # Example:
  #   {a: 1, b: 2}.transform {|v| v + 1 } # => {a: 2, b: 3}
  def transform_values(*keys, &block)
    self.dup.transform_values!(*keys, &block)
  end

  # same as transform, except that it mutates the current hash
  def transform_values!(*keys)
    keys = self.keys if keys.empty?
    keys.each do |key|
      self[key] = yield self[key]
    end
    self
  end

  # transforms the keys of the hash, retaining the original value
  # example::
  #   {'a' => 1}.transform_keys{|k, v| k.upcase} == {'A' => 1}
  # notes::
  #   This is different than the Rails transform_keys in that it also provides the value
  def transform_keys_with_values
    {}.tap do |transformed|
      self.each do |key, value|
        transformed[yield(key, value)] = value
      end
    end
  end

  # similar to dig but allows for values to be retrieved by a path string such as "locations.0.name"
  def value_path(path)
    path.split('.').reduce(self) do |a, b|
      if a
        if a.is_a?(Array)
          a[b.to_i]
        else
          a[b] || a[b.to_sym]
        end
      end
    end
  end

  # removes any keys with empty values
  def compact
    delete_if { |k, v| v.nil? }
  end
end
