module MagLev
  module Sidekiq
    module Reliable
      if defined?(::Mongoid::Document)
        class Document
          include ::Mongoid::Document
          field :msg
          field :created_at, type: Time, default: -> { Time.now }

          # requeues the job and then deletes this document
          def requeue!
            ::Sidekiq.redis do |conn|
              conn.rpush("queue:#{msg['queue']}", MultiJson.dump(msg))
            end
            delete
          end
        end
      end
    end
  end
end
