require 'spec_helper'

describe MagLev::Lock do

  describe '::lock_model' do
    let!(:model) { User.create(name: 'test') }
    let!(:copy) { User.find(model.id) }

    it 'control test' do
      model.name = 'new name'
      model.save!
      expect(copy.reload.name).to eq 'new name'
      expect(copy).to_not be_new_record
    end

    it 'should reload model if not acquired on the first attempt' do
      thr1 = Thread.new do
        MagLev::Lock.lock_model(model) do
          model.name = 'new name'
          model.save!
          expect(model).to_not be_changed
          sleep 0.5
        end
      end

      # make sure the first thread actually runs first
      sleep 0.1

      thr2 = Thread.new do
        MagLev::Lock.lock_model(copy) do
          # copy should have been reloaded automatically
          expect(copy.name).to eq 'new name'
          copy.extra = 'copy'
          copy.save
        end
      end

      thr1.join
      thr2.join

      expect(model.reload.extra).to eq 'copy'
    end
  end
end