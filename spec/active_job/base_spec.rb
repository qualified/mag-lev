require 'spec_helper'

class MyExampleJob < MagLev::ActiveJob::Base
  queue_as :default
  def perform(user)
    p user
    # user.name = 'async'
    # user.save!
  end
end

describe MagLev::ActiveJob::Base do
  include ActiveJob::TestHelper

  before { GlobalID.app = 'default' }
  let(:user) { User.create }
  let(:job) { MyExampleJob.perform_now(Struct.new(:a).new(1)) }

  it 'should update the user' do
    job
    expect(user.reload.name).to eq 'async'
  end
end