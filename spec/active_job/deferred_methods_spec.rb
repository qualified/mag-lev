require 'spec_helper'

class DeferableModel < Model
  include MagLev::ActiveJob::DeferredMethods

  field :name

  def set_name
    self.name = 'name set'
    save!
  end
end

describe MagLev::ActiveJob::DeferredMethods do
  let(:model) { DeferableModel.create }

  it 'should support being called with dsl' do
    model.deferred.set_name
    expect(model.name).to be_nil
    expect(model.reload.name).to eq 'name set'
    expect(MagLev::ActiveJob::DeferredMethods::Job.performed_jobs.count).to eq 1
  end

  it 'should support being called with options' do
    model.deferred(wait: 1.second).set_name
    expect(model.reload.name).to eq 'name set'
  end
end