require 'spec_helper'

class UniqueWorker
  include Sidekiq::Worker
  sidekiq_options globalid: true, yaml: true, unique: true

  def perform(model)
  end
end

describe MagLev::Sidekiq::UniqueJobs do
  let(:user) { User.create }

  before do
    MagLev.configure
    UniqueWorker.jobs.clear
  end

  it 'should only queue 1 unique item', sidekiq: :fake do
    UniqueWorker.perform_async(user)
    UniqueWorker.perform_async(user)
    expect(UniqueWorker.jobs.count).to eq 1
  end

  it 'should queue both items if not unique', sidekiq: :fake do
    UniqueWorker.set(unique: false).perform_async(user)
    UniqueWorker.set(unique: false).perform_async(user)
    expect(UniqueWorker.jobs.count).to eq 2
  end
end