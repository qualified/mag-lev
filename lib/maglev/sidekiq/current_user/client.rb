module MagLev
  module Sidekiq
    module CurrentUser
      class Client
        def call(worker_class, msg, queue, redis_pool)
          # if current_user is not explicitely disabled and there is a curent user then set the id
          if msg['current_user'] != false and current_user
            msg['current_user_id'] = current_user.id.to_s
          end

          yield
        end

        def current_user
          MagLev.config.current_user_class.current
        end
      end
    end
  end
end
