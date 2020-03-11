require 'active_model'
require 'globalid'

class Model
  include ActiveModel::AttributeMethods
  include ActiveModel::Model
  include ActiveModel::Dirty
  include ActiveModel::Serialization
  extend ActiveModel::Callbacks
  include GlobalID::Identification

  define_model_callbacks :create, :save, :update

  def self.store
    @store ||= {}
  end

  def self.find(id)
    raise "id cannot be nil" if id.nil?
    attrs = store[id.to_i]
    raise "Not Found" unless attrs
    new(attrs)._load
  end

  def self.field(name, default: nil, type: nil)
    define_attribute_methods name
    define_method(name) do
      value = attrs[name]
      if value.nil?
        value = attrs[name] = default.is_a?(Proc) ? default.call : default
      end
      value
    end
    define_method("#{name}=") do |value|
      send "#{name}_will_change!" unless attrs[name] == value
      attrs[name] = value
    end
  end

  def initialize(attrs = {})
    @attrs = HashWithIndifferentAccess.new(attrs || {})
    @attrs[:id] ||= rand(999_999_999_999_999)
    @new_record = true
    super()
  end

  def _load
    @new_record = false
    self
  end

  def id
    attrs[:id]
  end

  def attrs
    @attrs ||= HashWithIndifferentAccess.new
  end

  def as_json(options = nil)
    if options[:only]
      attrs.slice(options[:only])
    elsif options[:except]
      attrs.except(options[:except])
    else
      attrs
    end
  end

  def self.create(attrs = {})
    new(attrs).tap {|m| m.create }
  end

  def create(validate: true)
    raise "already created" if persisted?
    run_callbacks :save do
      run_callbacks :create do
        if !validate or valid?
          @new_record = false
          changes_applied
          self.class.store[id] = attrs.dup
          true
        else
          false
        end
      end
    end
  end

  def forget_attribute_assignments
    # prevents an error
  end

  def update(validate: true)
    raise "not created" unless persisted?
    run_callbacks :save do
      run_callbacks :update do
        if !validate or valid?
          changes_applied
          self.class.store[id] = attrs.dup
          true
        else
          false
        end
      end
    end
  end

  def persisted?
    !new_record?
  end

  def new_record?
    !!@new_record
  end

  def save(validate: true)
    persisted? ? update(validate: validate) : create(validate: validate)
  end

  def save!
    validate!
    save
  end

  def validate!
    raise 'validation error' unless validate
  end

  def destroy
    self.class.store.delete(id)
    @destroyed = true
  end

  def destroyed?
    !!@destroyed
  end

  def reload
    clear_changes_information
    @attrs = self.class.store[id]
    self
  end

  def ==(other)
    other.is_a?(self.class) && id.to_s == other.id.to_s
  end
end

class User < Model
  include MagLev::Broadcastable
  include MagLev::CurrentUser

  field :name
  field :extra
end