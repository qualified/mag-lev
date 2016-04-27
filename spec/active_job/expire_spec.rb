require 'spec_helper'

class ExpireJob < MagLev::ActiveJob::Base
  def perform
  end
end

describe MagLev::ActiveJob::Base do
  let(:job) { ExpireJob.new }

  it 'should execute if future expiration date' do
    job.enqueue(expires_at: 10.seconds.from_now)
    expect(ExpireJob.performed_jobs.count).to eq 1
  end

  it 'should execute if no expiration date' do
    job.enqueue
    expect(ExpireJob.performed_jobs.count).to eq 1
  end

  it 'should not execute if past expiration date' do
    job.enqueue(expires_at: 1.second.ago)
    expect(ExpireJob.performed_jobs.count).to eq 0
  end

  it 'should execute if future expires_in' do
    job.enqueue(expires_in: 10.seconds)
    expect(ExpireJob.performed_jobs.count).to eq 1
  end

  it 'should not execute if future expires_in' do
    job.enqueue(expires_in: -10.seconds)
    expect(ExpireJob.performed_jobs.count).to eq 0
  end
end