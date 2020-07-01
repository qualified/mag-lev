require 'spec_helper'

class ReliableJob < MagLev::ActiveJob::Base
  reliable true

  cattr_accessor :count
  cattr_accessor :found

  def perform(fail = false)
    ReliableJob.count = MagLev::ActiveJob::Reliable.count
    ReliableJob.found = MagLev::ActiveJob::Reliable.find_since(Time.now)
    raise "fail test" if fail
  end
end

describe MagLev::ActiveJob::Reliable do
  let(:user) { User.create }
  let(:job) { ReliableJob.new }

  before do
    ReliableJob.count = 0
    ReliableJob.found = nil
  end

  it 'should add items to redis while in progress' do
    job.enqueue
    expect(ReliableJob.count).to eq 1
    expect(ReliableJob.found.count).to eq 1
  end

  it 'should clear items from redis after completion' do
    job.enqueue
    expect(MagLev::ActiveJob::Reliable.count).to eq 0
  end

  it 'should clear items from redis after failure' do
    expect { ReliableJob.perform_later(true) }.to raise_error RuntimeError
    expect(ReliableJob.count).to eq 1
    expect(ReliableJob.found.count).to eq 1
    expect(MagLev::ActiveJob::Reliable.count).to eq 0
  end
end