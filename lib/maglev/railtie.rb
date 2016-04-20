module MagLev
  class Railtie < Rails::Railtie
    config.before_configuration do |app|
      app.config.paths.add "app/service_objects/concerns", eager_load: true
      app.config.paths.add "app/service_objects", eager_load: true
      app.config.paths.add "app/workers", eager_load: true
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