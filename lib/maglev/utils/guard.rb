module MagLev
  class Guard
    class Error < ArgumentError
    end

    # raises an error if the argument value is nil
    def self.nil(name, value, msg = "cannot be nil")
      if value.nil?
        raise Error.new("#{name} #{msg}")
      end
    end

    # raises an error if the argument value is blank
    def self.blank(name, value, msg = "cannot be blank")
      if value.blank?
        raise Error.new("#{name} #{msg} (actual = #{value.inspect})")
      end
    end

    # raises an error if the argument value is falsy
    def self.falsy(name, value)
      if !value
        raise Error.new("#{name} cannot be falsy (actual = #{value.inspect})")
      end
    end

    # raises an error if the argument value is falsy
    def self.not_number(name, value)
      unless value.is_a?(Number) or value.is_a?(Integer)
        raise Error.new("#{name} expeted to be an Integer or Float (actual = #{value.inspect})")
      end
    end

    # raises an error if the argument value is falsy
    def self.not_int(name, value)
      unless value.is_a?(Number)
        raise Error.new("#{name} expeted to be an Integer (actual = #{value.inspect})")
      end
    end

    def self.invalid(name, value)
      raise Error.new("#{name} is an invalid value (actual = #{value.inspect})")
    end

    def self.type(name, value, type, allow_nil: false)
      unless (allow_nil and value.nil?) or value.is_a?(type)
        raise Error.new("#{name} is not a type of #{type} (value = #{value.inspect})")
      end
    end

    def self.new_record(name, value, allow_nil: false)
      self.nil(name, value) unless allow_nil
      unless (allow_nil and value.nil?) or !value.try(:new_record?)
        raise Error.new("#{name} cannot be a new record (value = #{value.inspect})")
      end
    end
  end
end