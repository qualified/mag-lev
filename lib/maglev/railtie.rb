module MagLev
  def Railtie < Rails::Railtie
    config.autoload_paths << "#{Rails.root}/app/service_objects"
    config.autoload_paths << "#{Rails.root}/app/workers"
    config.autoload_paths << "#{Rails.root}/app/service_objects/concerns"
    config.autoload_paths << "#{Rails.root}/app/listeners"
    config.autoload_paths << "#{Rails.root}/app/serializers"

    initializer "maglev.configure_rails_initialization" do |app|
    end

    generators do
      "../../rails/generators/service_object/service_object_generator.rb"
    end
  end
end