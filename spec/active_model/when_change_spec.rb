require 'spec_helper'

class WhenChangeExample < Model
  include MagLev::ActiveModel::WhenChange

  field :name
  field :active

  field :name_results, default: -> {[]}
  field :active_results, default: -> {[]}

  attr_accessor :after_name_set

  when_change(:name)
    .from(nil).to_any.before_save { self.name_results << :nil_to_any }
    .from_any.to_any.before_save { self.name_results << :any_to_any }
    .from(nil).to_any.after_save { after_name_set.call(self) if after_name_set }
    .from("test").to("test2").before_save { self.name_results << :test2 }
    .from('a').to('b').after_save { self.active = true ; save }
    .from('b', 'e')
      .to('c', 'd').invalidate('not allowed')
      .to_any.invalidate { 'not allowed when active' if active }
    .from('protected').to_any.protect { raise 'not allowed!' }

  when_change(:active)
    .from(nil).to(true).after_save { puts self.changes ; self.name = 'a' ; save ;  }

end

describe MagLev::ActiveModel::WhenChange do
  let(:example) { WhenChangeExample.new }
  describe '#before_save' do
    it 'should handle multiple events' do
      example.name = 'test'
      example.save
      expect(example.name_results).to eq [:nil_to_any, :any_to_any]

      example.name_results.clear
      example.name = 'test2'
      example.save
      expect(example.name_results).to eq [:any_to_any, :test2]
    end
  end

  # it 'should prevent recursive call' do
  #   example.name = 'a'
  #   example.save
  #   example.name = 'b'
  #   example.save
  #   expect(example.name).to eq 'a'
  # end

  describe '#invalidate' do
    before do
      example.name = 'b'
      example.save
    end

    it 'should not set errors if change to doesnt match' do
      example.name = 'a'
      expect(example).to be_valid
    end

    it 'should set errors for the first values passed in' do
      example.name = 'c'
      expect(example).to be_invalid
    end

    it 'should set errors any of the values matches' do
      example.name = 'd'
      expect(example).to be_invalid
    end

    it 'should add a error message' do
      example.name = 'd'
      example.valid?
      expect(example.errors[:name].first).to eq 'not allowed'
    end

    it 'should support blocks' do
      example.name = 'f'
      example.active = true
      example.valid?
      expect(example.errors[:name].first).to eq 'not allowed when active'
    end
  end

  describe '#protected' do
    before do
      example.name = 'protected'
      example.save
    end

    it 'should raise an error if unprotected is used' do
      example.name = 'a'
      expect { example.save }.to raise_error
    end

    it 'should not raise an error if unprotected is used' do
      example.name = 'a'
      example.unprotected { example.save }
      expect(example.name).to eq 'a'
      expect(example).to_not be_changed
    end
  end
end