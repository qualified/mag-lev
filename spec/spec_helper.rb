$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rspec/core'
require 'rspec/mocks'
require 'rspec/its'
require 'rspec/active_job'
require 'sidekiq/testing'
require 'maglev'
require 'maglev/rspec'
require File.expand_path('../support/models', __FILE__)

MagLev::Rspec.configure

RSpec.configure do |config|
  ## Active Job:
  config.include(RSpec::ActiveJob)
end
