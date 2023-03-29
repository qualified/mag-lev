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

        def send(name, *args, **kwargs)
          options = @options.dup

          # if unique options are not set, assume true and set the key to a default
          if !options[:unique] && options[:unique] != false
            arguments = args.any? ? Digest::MD5.hexdigest(args.map(&:to_s).to_json) : "no-args"
            options[:unique] = { 'key' => "DeferredMethod:#{@obj.class.name}:#{@obj.id}:#{name}:#{arguments}" }
          end
          
          Job.set(options).perform_later(@obj, name, *args, **kwargs)
        end

        def method_missing(name, *args, **kwargs)
          if @obj.respond_to?(name)
            send(name, *args, **kwargs)
          else
            super
          end
        end
      end

      class Job < MagLev::ActiveJob::Base
        def logger_name
          "#{super} object class = #{@object&.class&.name}, method = #{@method}"
        end

        def perform(object, method, *args, **kwargs)
          @object = object
          @method = method

          MagLev::Statsd.perform("active_job.deferred_methods", { class: object.class.name, method: method }) do
            parts = method.to_s.split('.')
            path = object
            parts.each.with_index do |part, ndx|
              if ndx < parts.size - 1
                path = path.send(part)
              else
                path.send(part, *args, **kwargs)
              end
            end
          end
        end
      end
    end
  end
end