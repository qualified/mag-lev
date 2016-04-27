require 'spec_helper'


class UniqueJob < MagLev::ActiveJob::Base
  unique timeout: 20.minutes

  def perform(model)
  end
end

describe MagLev::ActiveJob::Unique do
  let(:user) { User.create }
  let(:job) { UniqueJob.new }

  it('should have a set unique value with a limit of 20 minutes') do
    expect(UniqueJob.extended_options[:unique]).to be_a Hash
    expect(job.extended_options[:unique]).to eq({'timeout' => 20.minutes})
  end

  it 'should only queue 1 unique item', active_job: :test do
    UniqueJob.perform_later(user)
    UniqueJob.perform_later(user)
    expect(UniqueJob.enqueued_jobs.count).to eq 1
  end

  it 'should queue both items if not unique', active_job: :test do
    UniqueJob.set(unique: false).perform_later(user)
    UniqueJob.set(unique: false).perform_later(user)
    expect(UniqueJob.enqueued_jobs.count).to eq 2
  end
end