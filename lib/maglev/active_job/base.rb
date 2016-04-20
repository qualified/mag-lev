require 'active_job'
require 'maglev/active_job/serialization'

module MagLev
  module ActiveJob
    class Base < ::ActiveJob::Base
      before_enqueue do |job|
        puts 222
      end
      after_enqueue do |job|
        puts 222
      end

      after_perform do |job|
        p 111
      end
    end
  end
end