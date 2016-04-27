class ServiceObjectGenerator < MagLev::BaseGenerator
  def create_context_file
    create_file "app/service_objects/#{model_path_root}/#{context_root.underscore}.rb", <<-FILE
class #{model_class_name}
  class #{context_root} < #{context_base_class_name}
    argument :#{model_name}, type: #{model_class_name}, guard: nil

    protected

    def on_perform
    end
  end
end
    FILE

  end

  def create_spec_file
    file_name = "spec/service_objects/#{model_path_root}/#{context_root.underscore}_spec.rb"
    create_file file_name, <<-FILE
require 'rails_helper'

describe #{context_class_name} do
  let(:#{model_name}) { create(:#{model_name}) }
  subject(:service) { #{context_class_name}.new(#{model_name}) }

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
      name = "#{model_class_name}::ServiceObject"
      begin
        name.to_const
      rescue
        defined?(ApplicationServiceObject) ? 'ApplicationServiceObject' : 'MagLev::ActiveJob::Base'
      end
    end
  end
end
