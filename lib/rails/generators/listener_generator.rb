class ListenerGenerator < MagLev::BaseGenerator
  def create_context_file
    create_file "app/listeners/#{class_name.underscore}_listener.rb", <<-FILE
class #{listener_class_name}
  # TODO: Add this class to your maglev initializer
end
    FILE

  end

  def create_spec_file
    file_name = "spec/listeners/#{class_name.underscore}_listener_spec.rb"
    create_file file_name, <<-FILE
require 'rails_helper'

describe #{class_name}Listener, listeners: #{listener_class_name} do
  let(:listener) { #{listener_class_name}.new }
  pending
end
    FILE
  end

  def listener_class_name
    "#{class_name}Listener"
  end
end

