module MagLev
  module Sidekiq
    # ensures that the MagLev store is unique for each job
    module Store
      class Server
        def call(worker_class, msg, queue)
          # we want to previous the previous state, just in case were are running in a context (i.e. test env) where
          # everything is actually not in its own thread
          previous = RequestStore.store[:maglev]
          begin
            RequestStore.store[:maglev] = nil
            yield
          ensure
            RequestStore.store[:maglev] = previous
          end
        end
      end
    end
  end
end
