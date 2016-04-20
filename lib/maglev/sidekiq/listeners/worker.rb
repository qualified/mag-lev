module MagLev
  module Sidekiq
    module Listeners
      # handles async listener methods
      class Worker
        include ::Sidekiq::Worker
        sidekiq_options listeners: :inherit, yaml: true, globalid: true, reliable: true

        def perform(listener_name, method_name, *args)
          MagLev::Statsd.perform("async_broadcast_workers.#{listener_name}", method_name) do
            # MagLev.broadcaster.instance_variable_set('@event', event)
            listener = MagLev.broadcaster.listener_instance(Object.const_get(listener_name))
            listener.send(method_name, *args)
            MagLev.logger.info "#{listener_name}.#{method_name} handled"
          end
        end
      end
    end
  end
end
