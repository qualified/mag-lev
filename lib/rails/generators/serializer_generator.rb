require 'rails/generators/base_generator.rb'

class ListenerGenerator < MagLev::BaseGenerator
  def create_context_file
    create_file "app/serializers/#{class_name.underscore}_serializer.rb", <<-FILE
class #{class_name}Serializer < MagLev::Serializer

end
    FILE

  end

  def create_spec_file
    file_name = "spec/serializers/#{class_name.underscore}_spec.rb"
    create_file file_name, <<-FILE
require 'rails_helper'

describe #{class_name}Serializer do
  let(:model) { create(:#{class_name.underscore}) }
  let(:serializer) { #{class_name}Serializer.new(model) }

  pending
end
    FILE
  end

  def base_serializer_class_name
    defined?(ApplicationSerializer) ? ApplicationSerializer : MagLev::Serializer
  end
end
