require 'sidekiq'
module MagLev
  class ServiceObjectWorker
    include ::Sidekiq::Worker
    include MagLev::ClassLogger

    def perform(*params)
      service_class.new(*params).execute
    end

    def service_class
      Object.const_get(self.class.name.gsub('::Worker', ''))
    end
  end
end