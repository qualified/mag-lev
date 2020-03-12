require 'spec_helper'

class OperationsExampleJob < MagLev::ActiveJob::Base
  cattr_accessor :stuff
  cattr_accessor :processed
  cattr_accessor :priority

  def perform(*args)
    OperationsExampleJob.stuff ||= 0
    OperationsExampleJob.processed ||= 0
    MagLev.operations_queue.push(1, 'example') do
      OperationsExampleJob.processed += 1
      OperationsExampleJob.priority = 1
    end
    do_stuff
    do_stuff
  end

  def do_stuff
    OperationsExampleJob.stuff += 1
    MagLev.operations_queue.push(2, 'example') do
      OperationsExampleJob.processed += 1
      OperationsExampleJob.priority = 2
    end
  end
end

module Sidekiq
  def self.server?
    true
  end
end

describe MagLev::ActiveJob::Operations do
  let(:user) { User.create }
  let(:job) { OperationsExampleJob.new }
  
  context 'without listeners' do
    it 'should not set listeners when they are turned off' do
      job.enqueue
      expect(OperationsExampleJob.stuff).to eq 2
      expect(OperationsExampleJob.processed).to eq 1
      expect(OperationsExampleJob.priority).to eq 2
    end
  end
end
