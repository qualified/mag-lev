require 'active_job'
require 'active_support/core_ext' # ActiveJob uses core exts, but doesn't require it
require 'maglev/active_job/extended_options'
require 'maglev/active_job/enhanced_serialize'
require 'maglev/active_job/arguments'
require 'maglev/active_job/unique'
require 'maglev/active_job/timeout'
require 'maglev/active_job/expiration'
require 'maglev/active_job/current_user'
require 'maglev/active_job/stats'
require 'maglev/active_job/slow_reporter'
require 'maglev/active_job/retry'
require 'maglev/active_job/reliable'
require 'maglev/active_job/listeners'
require 'maglev/active_job/store'
require 'maglev/active_job/test_helper'

unless ActiveJob::Base.method_defined?(:deserialize)
  require 'maglev/active_job/deserialize_monkey_patch'
end

module MagLev
  module ActiveJob
    class Base < ::ActiveJob::Base
      include ClassLogger
      include ExtendedOptions
      include EnhancedSerialize
      include Arguments
      include Store
      include Retry
      include Timeout
      include Expiration
      include Stats
      include SlowReporter
      include Unique
      include Reliable
      include Listeners
      include CurrentUser
      include TestHelper

      extended_option(:provider_options) { {} }

      def logger_name
        arguments = arguments.present? ? arguments : @serialized_arguments || []
        "[#{job_id}] #{arguments.map(&:to_s)}"
      end
    end
  end
end