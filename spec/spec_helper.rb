$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rspec/core'
require 'rspec/mocks'
require 'rspec/its'
require 'sidekiq/testing'
require 'maglev'
require 'maglev/rspec'
require File.expand_path('../support/models', __FILE__)

MagLev::Rspec.configure

RSpec.configure do |config|
  config.before :each do |example|
    if example.metadata[:sidekiq] == :fake
      Sidekiq::Testing.fake!
    else
      Sidekiq::Testing.inline!
    end
  end

  # tests that use mongoid should require the gem before requiring this file
  if defined?(Mongoid)
    Mongoid.configure do |config|
      config.connect_to(ENV['CI'] ? "mongoidal_#{Process.pid}" : 'mongoidal_test')
    end

    config.before(:each) do
      Mongoid.purge!
      Mongoid::IdentityMap.clear if defined?(Mongoid::IdentityMap)
    end

    config.after(:suite) do
      Mongoid::Threaded.sessions[:default].drop if ENV['CI']
    end
  end
end
