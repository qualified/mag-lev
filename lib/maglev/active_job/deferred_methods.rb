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
            parts = method.to_s.split('.')
            path = object
            parts.each.with_index do |part, ndx|
              if ndx < parts.size - 1
                path = path.send(part)
              else
                path.send(part, *args)
              end
            end
          end
        end
      end
    end
  end
end