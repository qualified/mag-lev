module MagLev
  class Lock
    attr_reader :key, :expiration

    def initialize(key, expiration = 10.minutes)
      raise "key cannot be blank" if key.blank?
      @key = key.is_a?(String) || key.is_a?(Symbol) ? key.to_s: "#{key.class.name}:#{key.to_json}"
      @expiration = expiration
    end

    def acquire
      MagLev.redis do |redis|
        redis.set(key, Time.now, nx: true, ex: @expiration).tap do |v|
          MagLev.logger.debug { "#{v ? 'Acquired lock' : 'Failed to acquire lock'} #{key}" }
        end
      end
    end

    def release
      MagLev.redis do |redis|
        if redis.del(key) == 1
          MagLev.logger.debug { "Released lock #{key}" }
          true
        else
          false
        end
      end
    end

    def locked?
      MagLev.redis do |redis|
        !!redis.get(key)
      end
    end

    def lock(attempts: 15, delay: 0.25)
      attempts.times do
        if acquire
          begin
            yield
          ensure
            release
          end
          return true
        else
          sleep delay
        end
      end
      return false
    end

    # will try to acquire a lock on an active model object. if it does not acquire the lock
    # on the first attempt then it will retry. If a retry is successful, it will reload the
    # model first to ensure that it has the latest data
    # NOTE: This method does not support nested calls, and will cause performance issues due
    #       to the nested lock calling sleep while waiting for the parent lock to finish.
    def self.lock_model(model, expiration: 10.seconds, attempts: 10, delay: 0.25, &block)
      # if a model is a new record there is no use in locking it since we don't support in-process
      # locking so just call the block immediately
      if model.new_record?
        block.call
        true
      else
        lock = self.new("#{model.class.name}:#{model.id.to_s}", expiration)

        attempts.times do |attempt|
          if lock.acquire
            begin
              if attempt > 0
                model.reload
                MagLev.logger.debug { "Acquired lock on attempt #{attempt}, reloaded model #{lock.key}" }
              end
              block.call
            ensure
              lock.release
            end
            return true
          else
            sleep delay
          end
        end
        MagLev.logger.warn { "Exhausted all #{attempts} attempts to acquire model lock for #{lock.key}" }
        false
      end
    end

    def self.lock_model!(model, options = {}, &block)
      raise AcquireLockError unless lock_model(model, options, &block)
    end

    class AcquireLockError < RuntimeError
    end
  end
end
