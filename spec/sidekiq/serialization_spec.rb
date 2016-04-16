require 'spec_helper'

class GlobalIdWorker
  include Sidekiq::Worker
  sidekiq_options globalid: true, yaml: true

  def perform(model, name)
    model.name = name
    model.save!
  end
end

describe MagLev::Sidekiq::Serialization do
  let(:user) { User.create }

  before { MagLev.configure }

  it 'should properly locate model' do
    GlobalIdWorker.perform_async(user, 'worker')
    expect(user.reload.name).to eq 'worker'
  end
end