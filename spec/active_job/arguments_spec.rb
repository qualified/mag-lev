require 'spec_helper'

class ArgumentsJob < MagLev::ActiveJob::Base
  include MagLev::ActiveJob::Arguments

  argument :name, type: String, guard: :nil
  argument :config, type: Hash, &:compact
  argument :sort, named: true, setter: true
  argument :limit, named: true, default: 10
end

class InheritedArgumentsJob < ArgumentsJob
  argument :other_name, type: String, guard: :nil
end

class InitArgsJob < MagLev::ActiveJob::Base
  # test that argument blocks work
  argument :name do |value|
    @has_name = value.present?
  end

  argument :config

  # test that after_arguments can be used
  after_arguments do
    @has_config = config.present?
  end

  def name_set?
    !!@has_name
  end

  def config_set?
    !!@has_config
  end
end

class DefaultArgJob < MagLev::ActiveJob::Base
  include MagLev::ActiveJob::Arguments
  argument :config, default: {}
  argument :config2, default: ->{{}}

  def perform(*)
  end
end

describe MagLev::ActiveJob::Arguments do

  let(:job) { ArgumentsJob.new("test", {a: 1}) }
  let(:inherited) { InheritedArgumentsJob.new("test", {a: 1}, 'inherited', sort: 'desc') }

  it 'should define getters' do
    expect(job.name).to eq 'test'
    expect(job.config).to eq(a: 1)
  end

  it 'should allow optional setters' do
    job.sort = 'abc'
    expect(job.sort).to eq 'abc'
  end

  it 'should raise an error if a nil value is given' do
    expect { job = ArgumentsJob.new(nil, {}) }.to raise_error
  end

  it 'should support procs as default values' do
    job = DefaultArgJob.new
    job.perform_now
    expect(job.config).to eq({})
    expect(job.config2).to eq({})
  end

  it 'should raise an error if a non-string is given' do
    expect { job = ArgumentsJob.new(1, {}) }.to raise_error
  end

  it 'should transform value if block is provided' do
    job = ArgumentsJob.new('test', {a: 1, b: nil})
    expect(job.config).to eq({a: 1})
  end

  it 'should support named values' do
    job = ArgumentsJob.new('test', {}, sort: 'asc')
    expect(job.limit).to eq 10
    expect(job.sort).to eq 'asc'
  end

  it 'should support named_arguments getter' do
    expect(job.named_arguments).to eq(sort: nil, limit: 10)
  end

  it 'should support default named values even if options are not provided' do
    expect(job.limit).to eq 10
  end

  describe 'inheritence' do
    it 'argument calls should be additive to parent' do
      expect(InheritedArgumentsJob.arguments.count).to eq 3
    end

    it 'should inherit guards from parents' do
      expect { InheritedArgumentsJob.new('test', nil, nil) }.to raise_error
    end

    it 'should support guards for newly added argument' do
      expect { InheritedArgumentsJob.new('test', {}, nil) }.to raise_error
    end

    it 'should support properties for newly added argument' do
      expect(inherited.other_name).to eq 'inherited'
    end

    it 'should handle named properties after newly defined arguments' do
      expect(inherited.sort).to eq 'desc'
    end

    it 'should support initialize_arguments' do
      job = InitArgsJob.new('a', {a: 1})
      expect(job).to be_config_set
      expect(job).to be_name_set
    end
  end
end