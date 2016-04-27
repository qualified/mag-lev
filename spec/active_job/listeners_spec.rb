require 'spec_helper'

class ListenerJob < MagLev::ActiveJob::Base
  unique false

  cattr_accessor :count

  def perform(*args)
    # p MagLev.broadcaster.listeners
    ListenerJob.count = MagLev.broadcaster.listeners.count
  end
end

describe MagLev::ActiveJob::Listeners do
  let(:user) { User.create }
  let(:job) { ListenerJob.new }

  before do
    ListenerJob.count = 0
  end

  context 'when manually listenining' do
    before do
      MagLev.broadcaster.listen(ListenerJob)
      expect(MagLev.broadcaster.listeners.count).to eq 1
    end

    it 'should not set listeners when they are turned off' do
      job.enqueue(listeners: false)
      expect(ListenerJob.count).to eq 0
    end

    it 'should set listeners when they are explicitly inherited' do
      job.enqueue(listeners: :inherit)
      expect(ListenerJob.count).to eq 1
    end
  end

  it 'should configure registered listeners when true', listeners: ListenerJob do
    expect(MagLev.broadcaster.listeners.count).to eq 1
    job.enqueue(listeners: true)
    expect(ListenerJob.count).to eq 1
  end
end