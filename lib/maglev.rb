require 'request_store'
require 'active_support'

require 'maglev/version'
require 'maglev/errors'
require 'maglev/config'
require 'maglev/current_user'
require 'maglev/logger'
require 'maglev/utils/guard'
require 'maglev/utils/try'
require 'maglev/utils/class_logger'
require 'maglev/utils/event_reporter'
require 'maglev/utils/lock'
require 'maglev/utils/memo'
require 'maglev/utils/memory_stores'
require 'maglev/utils/operations_queue'
require 'maglev/statsd'
require 'maglev/facets/hash'
require 'maglev/facets/object'
require 'maglev/facets/parameters'
require 'maglev/facets/string'
require 'maglev/serialization/serializer'
require 'maglev/serialization/model_response_serializer'
require 'maglev/serialization/hash_serializer'
require 'maglev/active_model/when_change'
require 'maglev/active_model/unit_of_work'
require 'maglev/active_job/base'
require 'maglev/active_job/service_object'
require 'maglev/active_job/deferred_methods'
require 'maglev/listeners/broadcaster'
require 'maglev/listeners/broadcastable'
require 'maglev/listeners/event'
require 'maglev/integrations/sidekiq' if defined?(Sidekiq)
require 'maglev/railtie' if defined?(Rails)

module MagLev

  class << self
    include MagLev::Memo

    def request_store
      RequestStore.store[:maglev] ||= {}
    end

    # operations queue. Automatically drained for each job and request, all
    # others must manually drained
    def operations_queue
      request_store[:operations_queue] ||= MagLev::OperationsQueue.new
    end

    # true if running within web process. Considered to be true if not running in a rake/sidekiq/console process
    def web?
      !console? && !rake? && !sidekiq?
    end

    def sidekiq?
      defined?(::Sidekiq) ? !!::Sidekiq.server? : false
    end

    def rake?
      File.split($0).last.include? 'rake'
    end

    def console?
      !!defined?(Rails::Console)
    end

    def test?
      (defined?(Rails.env) && Rails.env.test?) || !!defined?(RSpec)
    end

    def production?
      env_name == 'production'
    end

    def process_type
      if console? then 'console'
      elsif rake? then 'rake'
      elsif sidekiq? then 'sidekiq'
      elsif test? then 'test'
      else 'web'
      end
    end

    def env_name
      @env_name ||= defined?(Rails.env) ? Rails.env : (test? ? 'test' : 'default')
    end
    attr_writer :env_name

    # finds the environment value that is not blank
    def env(*keys)
      keys.map{|key| ENV[key]}.find {|v| !v.blank?}
    end

    def env_int(*keys)
      v = self.env(*keys)
      v ? v.to_i : v
    end

    # useful when working within dev environments and configuring fallback urls.
    def docker_or_local(port = nil)
      "#{docker_ip.present? ? docker_ip : 'localhost'}#{port ? ":#{port}" : ""}"
    end

    # Utility for finding the IP of the docker-machine instance on the machine.
    memo def docker_ip(machine_name = 'default')
      @docker_ip ||= if ENV['DOCKER_HOSTS']
        ENV['DOCKER_HOST'].gsub(/tcp:\/\/|:\d*/, '')
      else
        ip = `docker-machine ip #{machine_name}` rescue nil
        if !ip
          nil
        elsif ip.include? 'Error'
          nil
        else
          ip ? ip.gsub("\n", '') : nil
        end
      end
    end

    # passes a redis instance into the block provided. If Sidekiq is loaded then this will
    # draw from its connection pool, otherwise Redis.current will be passed in.
    def redis(&block)
      if defined?(::Sidekiq)
        ::Sidekiq.redis(&block)
      else
        # TODO: utilize config and our own connection pool
        block.call(Redis.current)
      end
    end
  end
end

