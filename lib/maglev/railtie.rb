module MagLev
  class Railtie < Rails::Railtie
    initializer "after_action_operations_queue" do
      if defined?(ApplicationController)
        ApplicationController.after_action do
          MagLev.operations_queue.drain
        end
      end
    end

    config.before_configuration do |app|
      app.config.paths.add "app/service_objects/concerns", eager_load: true
      app.config.paths.add "app/service_objects", eager_load: true
      app.config.paths.add "app/listeners", eager_load: true
      app.config.paths.add "app/serializers", eager_load: true
    end

    generators do
      require "rails/generators/base_generator.rb"
      require "rails/generators/service_object_generator.rb"
      require "rails/generators/serializer_generator.rb"
      require "rails/generators/listener_generator.rb"
    end
  end
end