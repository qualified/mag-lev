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
  # clean out the queue after each spec
  config.after(:each) do
    ActiveJob::Base.queue_adapter.enqueued_jobs = []
    ActiveJob::Base.queue_adapter.performed_jobs = []
  end

  config.before :each do |example|
    case example.metadata[:activejob]
      when :sidekiq
        ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::SidekiqAdapter.new
      when :inline
        ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::InlineAdapter.new
      else
        ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::TestAdapter.new
    end
  end

  ## Sidekiq:

  config.before :each do |example|
    if example.metadata[:sidekiq] == :fake
      Sidekiq::Testing.fake!
    else
      Sidekiq::Testing.inline!
    end
  end
end
