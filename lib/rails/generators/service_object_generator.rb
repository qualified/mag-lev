require 'rails/generators/base_generator.rb'

class ServiceObjectGenerator < MagLev::BaseGenerator
  def create_context_file
    create_file "app/service_objects/#{file_path}.rb", <<-FILE
class #{namespace_class}
  class #{class_parts.last} < #{context_base_class_name}
    argument :#{namespace_parts.last.underscore}, type: #{namespace_class}, guard: :nil

    protected

    def on_perform
    end
  end
end
    FILE

  end

  def create_spec_file
    file_name = "spec/service_objects/#{file_path}_spec.rb"
    create_file file_name, <<-FILE
require 'rails_helper'

describe #{class_name} do
  let(:#{namespace_parts.last.underscore}) { create(:#{namespace_parts.last.underscore}) }
  subject(:service) { #{class_name}.new(#{namespace_parts.last.underscore}) }

  describe '#perform' do
    it 'performs without raising an error' do
      expect { service.perform_now }.to_not raise_error
    end
  end

  describe '#perform_later' do
    it_behaves_like 'Background Job'
  end
end
    FILE
  end

  protected

  def context_base_class_name
    @view_model_base_class_name ||= begin
      name = "#{namespace_class}::ServiceObject"
      begin
        name.to_const
      rescue
        'ApplicationServiceObject'
      end
    end
  end
end
