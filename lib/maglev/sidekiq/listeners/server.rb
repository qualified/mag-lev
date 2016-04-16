module MagLev
  module Sidekiq
    module Listeners
      class Server
        def call(worker_class, msg, queue)
          config = msg['listeners']
          if MagLev.config.listeners.enabled
            if config.is_a? Array
              MagLev.broadcaster.listeners.clear
              MagLev.broadcaster.listen(*config.map {|l| Object.const_get(l)})

            # if config is false or the value was left as inherit by the client middleware,
            # then we are not supposed to use listeners
            elsif config == false or config == 'inherit'
              MagLev.broadcaster.disable!

              if config == 'inherit'
                Rails.logger.info 'Event dispatch is disabled due to the server inheriting a disabled dispatcher'
              end
            end
          end

          yield
        end
      end
    end
  end
end
