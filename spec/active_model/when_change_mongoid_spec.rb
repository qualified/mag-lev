require 'spec_helper'
require 'mongoid'

Mongoid.load_configuration(
  clients: {
    default: {
      database: 'maglev_test',
      hosts: [ENV.fetch('MONGODB_HOST', 'localhost:27017')],
      options: { server_selection_timeout: 5 }
    }
  }
)
Mongoid.logger.level = Logger::WARN

# Mongoid 8 reports `attribute_was` as the new value inside after_* callbacks,
# so these specs only pass if when_change reads the pre-save value another way.
class WhenChangeMongoidExample
  include Mongoid::Document
  include MagLev::ActiveModel::WhenChange

  field :name
  field :active
  field :results, default: -> { [] }

  when_change(:name)
    .from(nil).to_any.after_save { results << :nil_to_any }
    .from_any.to_any.after_save { results << :any_to_any }
    .from('a').to('b').after_save { results << :a_to_b }
    .from('b', 'e').to('c', 'd').after_save { results << :multi_from }
    .from(nil).to('create').after_create { results << :after_create }
    .from('x').to('y').after_update { results << :after_update }
    .from('r').to('s').after_save { self.active = true; save }

  when_change(:active)
    .from(nil).to(true).after_save { results << :active_set }
end

describe MagLev::ActiveModel::WhenChange, 'with Mongoid after_* callbacks' do
  let(:example) { WhenChangeMongoidExample.new }

  before { WhenChangeMongoidExample.delete_all }

  it 'fires from nil to any' do
    example.name = 'test'
    example.save!
    expect(example.results).to include(:nil_to_any)
  end

  it 'fires from_any to_any' do
    example.name = 'test'
    example.save!
    expect(example.results).to include(:any_to_any)
  end

  it 'fires value to value' do
    example.name = 'a'
    example.save!
    example.results.clear
    example.name = 'b'
    example.save!
    expect(example.results).to eq [:any_to_any, :a_to_b]
  end

  it 'fires with multiple from values' do
    example.name = 'e'
    example.save!
    example.results.clear
    example.name = 'd'
    example.save!
    expect(example.results).to include(:multi_from)
  end

  it 'fires after_create' do
    example.name = 'create'
    example.save!
    expect(example.results).to include(:after_create)
  end

  it 'fires after_update' do
    example.name = 'x'
    example.save!
    example.name = 'y'
    example.save!
    expect(example.results).to include(:after_update)
  end

  it 'does not fire when the value is unchanged' do
    example.name = 'a'
    example.save!
    example.results.clear
    example.save!
    expect(example.results).to be_empty
  end

  it 'supports a recursive save inside after_save' do
    example.name = 'r'
    example.save!
    example.name = 's'
    example.save!
    expect(example.reload.active).to eq true
    expect(example.results).to include(:active_set)
  end
end
