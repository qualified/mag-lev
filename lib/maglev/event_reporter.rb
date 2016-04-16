module MagLev
  # integrates 3rd party error/event reporting libraries into a unified service
  class EventReporter
    def self.info(*args)
      log(:info, *args)
    end

    def self.warn(*args)
      log(:warn, *args)
    end

    def self.error(*args)
      log(:error, *args)
    end

    def self.fatal(*args)
      log(:fatal, *args)
    end

    def self.log(level, *args)
      if Rails.respond_to?(:env) and not Rails.env.test?
        ::Rollbar.send(level == :fatal ? :critical : level, *args) if defined?(::Rollbar)
        log_raven(level, *args) if defined?(Raven)
      end
    end

    def self.context
      MagLev.request_store[:event_reporter_context] ||= {}
    end

    # sets contextual information for the duration of the block
    def self.with_context(key, data)
      existing = context[key]
      yield
      context[key] = existing
    end

    def self.log_raven(level, *args)
      str = args.find {|a| a.is_a?(String) }
      ex = args.find {|a| a.is_a?(Exception) }
      hash = args.find {|a| a.is_a?(Hash) } || {}

      hash[:message] = str if str and ex

      method = ex ? :capture_exception : :capture_message

      options = {level: level}

      if hash
        options[:extra] = hash
        options[:fingerprint] = hash.delete(:fingerprint) if hash[:fingerprint]
        options[:user] = hash.delete(:user) if hash[:user]
      end

      options[:fingerprint] ||= [str] if str

      Raven.send(method, ex || str, options)
    end
  end


end
