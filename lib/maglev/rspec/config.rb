module MagLev
  module Rspec
    def self.configure(options = {})
      RSpec.configure do |config|
        config.around :each do |example|
          MagLev::Rspec.clear_state
          MagLev::Rspec.configure_listeners(example.metadata[:listeners]) do
            example.run
          end
        end
      end
    end

    # reset any shared state
    def self.clear_state
      RequestStore.store[:maglev] = nil
    end

    # support the ability to easily configure listener groups and instances on a per test basis
    def self.configure_listeners(listeners)
      if listeners
        if listeners == true
          MagLev.broadcaster.listen(*MagLev.config.listeners.registration_classes)
        else
          MagLev.broadcaster.listen(*listeners)
        end
      end
      yield
    end
  end
end