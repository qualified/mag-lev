require 'spec_helper'

class ExampleServiceObject < MagLev::ActiveJob::ServiceObject
  argument :name, type: String, guard: :nil

  attr_reader :new_name

  protected

  def on_perform
    @new_name = "new #{name}"
  end
end


describe MagLev::ActiveJob::ServiceObject do
  let(:so) { ExampleServiceObject.new('name') }

  it 'should support arguments' do
    expect(so.name).to eq 'name'
  end

  it 'should mark as performed when enqueued' do
    so.enqueue
    expect(ExampleServiceObject.performed_jobs.first).to be_performed
  end
end