require 'spec_helper'

class BaseExampleJob < MagLev::ActiveJob::Base
  queue_as :default
  def perform(user)
    user.name = 'async'
    user.save!
  end
end

describe MagLev::ActiveJob::Base do
  include ActiveJob::TestHelper

  before { GlobalID.app = 'default' }
  let(:user) { User.create }
  let(:job) { BaseExampleJob.perform_later(user) }

  it 'should update the user' do
    job
    expect(user.reload.name).to eq 'async'
  end

  it 'should have provider_options' do
    expect(job.extended_options['provider_options']).to eq({})
  end
end