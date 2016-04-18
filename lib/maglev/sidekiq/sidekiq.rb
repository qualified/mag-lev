require 'sidekiq'
require 'maglev/sidekiq/unique_jobs/client'
require 'maglev/sidekiq/unique_jobs/context'
require 'maglev/sidekiq/unique_jobs/server'

require 'maglev/sidekiq/listeners/client'
require 'maglev/sidekiq/listeners/server'
require 'maglev/sidekiq/listeners/worker'

require 'maglev/sidekiq/current_user/client'
require 'maglev/sidekiq/current_user/server'

require 'maglev/sidekiq/serialization/client'
require 'maglev/sidekiq/serialization/server'

if defined?(Mongoid)
  require 'maglev/sidekiq/reliable/server'
  require 'maglev/sidekiq/reliable/document'
end

require 'maglev/sidekiq/statsd/server'
require 'maglev/sidekiq/statsd/client'
require 'maglev/sidekiq/statsd/heartbeat'

require 'maglev/sidekiq/slow_reporter/server'
require 'maglev/sidekiq/errors/server'
require 'maglev/sidekiq/timeout/server'
require 'maglev/sidekiq/store/server'

module MagLev
  module Sidekiq
  end
end