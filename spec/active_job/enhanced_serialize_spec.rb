require 'spec_helper'

class EnhancedSerializeJob < MagLev::ActiveJob::Base
  enhanced_serialize true
  queue_as :default

  cattr_accessor :yaml_name
  cattr_accessor :serialized
  cattr_accessor :hash

  def perform(user, yaml, hash = nil)
    user.name = 'async'
    user.save!

    EnhancedSerializeJob.serialized = serialized?
    EnhancedSerializeJob.yaml_name = yaml.name
    EnhancedSerializeJob.hash = hash
  end
end

class YamlExample
  attr_accessor :name
end

describe MagLev::ActiveJob::EnhancedSerialize do
  let(:user) { User.create }
  let(:yaml) { YamlExample.new }
  let(:job) { EnhancedSerializeJob.new(user, yaml) }

  before do
    EnhancedSerializeJob.yaml_name = nil
    EnhancedSerializeJob.serialized = false
    EnhancedSerializeJob.hash = nil
  end

  it 'should support both global id and yaml' do
    yaml.name = 'yaml'
    job.enqueue
    expect(user.reload.name).to eq 'async'
    expect(EnhancedSerializeJob.yaml_name).to eq 'yaml'
  end

  describe 'hash serialization' do
    context 'global id' do
      it 'should load the object from the store' do
        job.arguments << {user: user}
        job.enqueue
        expect(EnhancedSerializeJob.hash[:user]).to_not be user
        expect(EnhancedSerializeJob.hash[:user]).to eq user
      end
    end

  end

  describe '#was_serialized?' do
    it 'should be false when job was performed now' do
      expect(job).to_not be_serialized
    end
    
    it 'should be false when job was performed now' do
      job.enqueue
      expect(EnhancedSerializeJob.serialized).to be true
    end
  end
end