require 'request_store'
require 'maglev/version'
require 'maglev/errors'
require 'maglev/guard'
require 'maglev/config'
require 'maglev/current_user'
require 'maglev/logger'
require 'maglev/try'
require 'maglev/statsd'
require 'maglev/class_logger'
require 'maglev/event_reporter'
require 'maglev/lock'
require 'maglev/serialization/serializer'
require 'maglev/serialization/model_response_serializer'
require 'maglev/serialization/hash_serializer'
require 'maglev/service_object'
require 'maglev/service_object_worker'
require 'maglev/active_model/when_change'
require 'maglev/active_model/unit_of_work'
require 'maglev/listeners/broadcaster'
require 'maglev/listeners/broadcastable'
require 'maglev/listeners/event'
require 'maglev/sidekiq/sidekiq'
require 'maglev/railtie' if defined?(Rails)

module MagLev
  def self.config
    @config ||= MagLev::Config.new
  end

  def self.configure
    yield(config) if block_given?
    config.send(:apply)
  end

  def self.request_store
    RequestStore.store[:maglev] ||= {}
  end

  # true if running within web process. Considered to be true if not running in a rake/sidekiq/console process
  def self.web?
    !console? && !rake? && !sidekiq?
  end

  def self.sidekiq?
    !!::Sidekiq.server?
  end

  def self.rake?
    File.split($0).last.include? 'rake'
  end

  def self.console?
    !!defined?(Rails::Console)
  end

  def self.test?
    (defined?(Rails.env) && Rails.env.test?) || !!defined?(RSpec)
  end

  def self.process_type
    if console? then 'console'
    elsif rake? then 'rake'
    elsif sidekiq? then 'sidekiq'
    elsif test? then 'test'
    else 'web'
    end
  end

  # finds the environment value that is not blank
  def self.env(*keys)
    keys.map{|key| ENV[key]}.find {|v| !v.blank?}
  end

  def self.env_int(*keys)
    v = self.env(*keys)
    v ? v.to_i : v
  end
end

