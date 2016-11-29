module MagLev
  module ActiveJob
    class AsyncJob < MagLev::ActiveJob::Base
      listeners :inherit
      #reliable true

      def perform(listener_name, method_name, args)
        MagLev::Statsd.perform("active_job.async_broadcasts.#{listener_name}", method_name) do
          # MagLev.broadcaster.instance_variable_set('@event', event)
          listener = MagLev.broadcaster.listener_instance(Object.const_get(listener_name))
          listener.send(method_name, *args)
          logger.info "#{listener_name}.#{method_name} handled"
        end
      end
    end
  end
end