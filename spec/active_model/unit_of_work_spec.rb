require 'spec_helper'

class UnitOfWorkExample < Model
  include MagLev::ActiveModel::UnitOfWorkable
  field :label
  validates :label, presence: true

end

class NonUnitOfWorkExample < Model
  field :label
  validates :label, presence: true
end

describe 'test' do
  it 'should be cool' do
    e = UnitOfWorkExample.new
    e.label = 'dfd'
    e.save
    p e
  end
end

describe MagLev::ActiveModel::UnitOfWorkable do
  let(:e1) { UnitOfWorkExample.new(label: 'good') }
  let(:e2) { UnitOfWorkExample.new }
  let(:e3) { NonUnitOfWorkExample.create(label: 'a') }

  it 'should not save until after the work has completed' do
    MagLev.unit_of_work do
      e1.save!
      expect(e1).to be_new_record
    end

    expect(e1).to_not be_new_record
  end

  it 'should support arbitray actions' do
    name = nil
    MagLev.unit_of_work do |work|
      e1.save!
      work.add do
        name = "good"
      end
      expect(name).to be_nil
    end

    expect(name).to eq "good"
  end

  it 'should not save if there is a failure' do
    begin
      MagLev.unit_of_work(true) do |t|
        e1.save!
        e2.save!
      end
    rescue
      expect(e1).to be_new_record
    end
  end

  it 'should support nested unit of works' do
    begin
      MagLev.unit_of_work do
        e1.save!
        MagLev.unit_of_work do
          e2.save!
        end
      end
    rescue
      expect(e1).to be_new_record
    end
  end

  it 'should support nested unit of works with ability to commit nested' do
    begin
      MagLev.unit_of_work do
        MagLev.unit_of_work do |t|
          e1.save!
          t.commit!
        end
        e2.save!
      end
    rescue
      expect(e1).to_not be_new_record
    end
  end

  it 'should support save' do
    MagLev.unit_of_work do
      e1.label = 'save'
      expect(e1.save).to eq true
      expect(e1.label).to eq 'save'
      expect(e1).to be_changed
    end
    
    expect(e1.label).to eq 'save'
    expect(e1).to_not be_changed
  end
  
  it 'should support models that do not have unit_of_workable mixed in' do
    MagLev.unit_of_work do |t|
      t.add(e3, :save)
      e3.label = 'b'
      expect(e3).to be_changed
    end

    expect(e3).to_not be_changed
    expect(e3.reload.label).to eq 'b'
  end

  it 'should support save method' do
    MagLev.unit_of_work do |t|
      t.save(e3)
      e3.label = 'b'
      expect(e3).to be_changed
    end

    expect(e3).to_not be_changed
    expect(e3.reload.label).to eq 'b'
  end

  context 'locking' do
    it 'should acquire a lock and only release it onces it completes' do
      MagLev.unit_of_work(lock: true) do |t|
        t.lock!(e1)
        expect(MagLev::Lock.new(e1.id.to_s)).to be_locked
      end
      expect(MagLev::Lock.new(e1.id.to_s)).not_to be_locked
    end

    it 'should release lock when error is raised' do
      begin
        MagLev.unit_of_work(lock: true) do |t|
          t.lock!(e1)
          expect(MagLev::Lock.new(e1.id.to_s)).to be_locked
          raise 'error'
        end
      rescue
        expect(MagLev::Lock.new(e1.id.to_s)).not_to be_locked
      end
    end
  end
end