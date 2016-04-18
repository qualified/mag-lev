module MagLev
  class Railtie < Rails::Railtie
    config.before_configuration do |app|
      app.config.autoload_paths << "#{Rails.root}/app/service_objects"
      app.config.autoload_paths << "#{Rails.root}/app/workers"
      app.config.autoload_paths << "#{Rails.root}/app/service_objects/concerns"
      app.config.autoload_paths << "#{Rails.root}/app/listeners"
      app.config.autoload_paths << "#{Rails.root}/app/serializers"
    end

    generators do
      require "rails/generators/base_generator.rb"
      require "rails/generators/service_object/service_object_generator.rb"
    end
  end
end