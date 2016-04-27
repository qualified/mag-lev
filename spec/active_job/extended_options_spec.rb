require 'spec_helper'


class ExtendedOptionsJob < MagLev::ActiveJob::Base
  extended_option :class_default do
    rand(100) + 2
  end

  extended_option :no_default
  extended_option :static_default, 1
  extended_option :static_instance
  extended_option :dynamic_instance

  static_instance 1
  dynamic_instance do
    rand(100) + 2
  end

  cattr_accessor :instance_options

  def perform
    ExtendedOptionsJob.instance_options = extended_options
  end
end

describe MagLev::ActiveJob::ExtendedOptions do
  let(:user) { User.create }
  let(:job) { ExtendedOptionsJob.new }

  it 'should have a generated class default' do
    expect(job.extended_options[:class_default]).to be > 1
  end

  it 'should support static defaults' do
    expect(ExtendedOptionsJob.extended_options[:static_default]).to eq 1
    expect(job.extended_options[:static_default]).to be 1
  end

  it 'should support no defaults' do
    expect(job.extended_options[:no_default]).to be nil
  end

  it 'should support instance blocks' do
    expect(job.extended_options[:dynamic_instance]).to be > 1
  end

  it 'should serialize all options' do
    serialized = job.serialize
    expect(serialized['no_default']).to be nil
    expect(serialized['static_default']).to eq 1
    expect(serialized['class_default']).to be > 1
    expect(serialized['dynamic_instance']).to be > 1
  end

  it 'should deserialize instance options correctly' do
    ExtendedOptionsJob.set(no_default: 2, static_default: 3).perform_later
    expect(ExtendedOptionsJob.instance_options['no_default']).to eq 2
    expect(ExtendedOptionsJob.instance_options['static_default']).to eq 3
    expect(ExtendedOptionsJob.instance_options['class_default']).to be > 1
    expect(ExtendedOptionsJob.instance_options['dynamic_instance']).to be > 1
  end
end