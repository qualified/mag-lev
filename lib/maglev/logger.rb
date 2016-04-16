module MagLev
  def self.logger
    @logger ||= if defined?(Rails) and Rails.respond_to?(:logger)
      Rails.logger
    else
      StdOutLogger.new
    end
  end

  class StdOutLogger
    def method_missing(method, *args, &block)
      if block_given?
        puts block.call
      else
        puts args
      end
    end
  end
end