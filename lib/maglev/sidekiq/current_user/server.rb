module MagLev
  module Sidekiq
    module CurrentUser
      class Server
        def call(worker_class, msg, queue)
          # if the current user is set, then set them to lazy load if User.current is called
          if msg['current_user_id'] and msg['current_user'] != false
            MagLev.config.current_user_class.current = Proc.new do
              MagLev.config.current_user_class.find(msg['current_user_id'])
            end
          end
          yield
        end
      end
    end
  end
end
