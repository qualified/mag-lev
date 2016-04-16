require 'active_model'
require 'globalid'

class Model
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
    attributes = store[id.to_i]
    raise "Not Found" unless attributes
    new(attributes)._load
  end

  def self.field(name, default: nil, type: nil)
    define_attribute_methods name
    define_method(name) do
      value = attributes[name]
      if value.nil?
        value = attributes[name] = default.is_a?(Proc) ? default.call : default
      end
      value
    end
    define_method("#{name}=") do |value|
      send "#{name}_will_change!" unless attributes[name] == value
      attributes[name] = value
    end
  end

  def initialize(attributes = {})
    @attributes = HashWithIndifferentAccess.new(attributes || {})
    @attributes[:id] ||= rand(999_999_999_999_999)
    @new_record = true
    super()
  end

  def _load
    @new_record = false
    self
  end

  def id
    attributes[:id]
  end

  def attributes
    @attributes ||= HashWithIndifferentAccess.new
  end

  def as_json(options = nil)
    if options[:only]
      attributes.slice(options[:only])
    elsif options[:except]
      attributes.except(options[:except])
    else
      attributes
    end
  end

  def self.create(attributes = {})
    new(attributes).tap {|m| m.create }
  end

  def create(validate: true)
    raise "already created" if persisted?
    run_callbacks :save do
      run_callbacks :create do
        if !validate or valid?
          @new_record = false
          changes_applied
          self.class.store[id] = attributes
          true
        else
          false
        end
      end
    end
  end

  def update(validate: true)
    raise "not created" unless persisted?
    run_callbacks :save do
      run_callbacks :update do
        if !validate or valid?
          changes_applied
          self.class.store[id] = attributes
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

  def destroy
    self.class.store.delete(id)
    @destroyed = true
  end

  def destroyed?
    !!@destroyed
  end

  def reload
    clear_changes_information
    @attributes = self.class.store[id]
    self
  end
end

class User < Model
  include MagLev::Broadcastable
  include MagLev::CurrentUser

  field :name
  field :extra
end