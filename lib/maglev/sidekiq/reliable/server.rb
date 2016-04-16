module MagLev
  module Sidekiq
    # an attempt at introducing the ability to catch lost jobs so that we can retry them later
    module Reliable
      class Server
        def call(worker_class, msg, queue)
          # if reliable is set to true, we will create a mongoid document to hold the fact that we are
          # currently working on a job. If the job completes or fails, we will delete the document.
          # We allow failures because Sidekiq handles these for us and will create a new job.
          # We are only concerned with the process quiting before any of that can happen.
          if !!msg['reliable']
            document = Document.with(write: { w: 0 }).create(msg: msg) rescue nil
            begin
              yield
            ensure
              document.with(write: { w: 0 }).delete if document
            end
          else
            yield
          end
        end
      end
    end
  end
end
