require 'spec_helper'

class RetryJob < MagLev::ActiveJob::Base
  def perform(*args)
    self.class.tries += 1
    raise "Fail, you must"
  end

  cattr_accessor :tries
end

describe MagLev::ActiveJob::Retry do
  let(:user) { User.create }
  let(:job) { RetryJob.new }

  before do
    MagLev.config.active_job.test_mode = false
    RetryJob.tries = 0
  end

  after do
    MagLev.config.active_job.test_mode = true
  end

  it 'should support being retried only once' do
    expect { job.enqueue(retry_limit: 1, unique: false) }.to raise_error
    expect(RetryJob.tries).to eq 2
  end

  it 'should default to no retries within test environment' do
    expect { job.enqueue(unique: false) }.to raise_error
    expect(RetryJob.tries).to eq 1
  end

  it 'uniqueness should not get in the way' do
    expect { job.enqueue(retry_limit: 2) }.to raise_error('Fail, you must')
    expect(RetryJob.tries).to eq 3
  end
end