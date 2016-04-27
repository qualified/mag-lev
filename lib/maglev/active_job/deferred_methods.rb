module MagLev
  module ActiveJob
    module DeferredMethods
      extend ActiveSupport::Concern

      def deferred(options = {})
        Deferred.new(self, options)
      end

      class Deferred
        def initialize(obj, options)
          @obj = obj
          @options = options
        end

        def method_missing(name, *args)
          if @obj.respond_to?(name)
            Job.set(@options).perform_later(@obj, name, *args)
          else
            super
          end
        end
      end

      class Job < MagLev::ActiveJob::Base
        def perform(object, method, *args)
          MagLev::Statsd.perform("active_job.deferred_methods.#{object.class.name}.#{method}") do
            object.send(method, *args)
          end
        end
      end
    end
  end
end