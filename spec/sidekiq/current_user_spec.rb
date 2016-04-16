require 'spec_helper'

class CurrentUserExampleWorker
  include Sidekiq::Worker
  sidekiq_options current_user: true
  class << self
    attr_accessor :value
  end

  def perform
    self.class.value = User.current
  end
end

class IgnoreCurrentUserExampleWorker
  include Sidekiq::Worker
  sidekiq_options current_user: false
  class << self
    attr_accessor :value
  end

  def perform
    self.class.value = User.current
  end
end

describe MagLev::Sidekiq::CurrentUser do
  let(:user) { User.create }
  before do
    MagLev.configure do |config|
      config.current_user_class = :User
    end
    user.make_current
  end

  it 'should load user if one is set and current_user is true' do
    CurrentUserExampleWorker.perform_async
    expect(CurrentUserExampleWorker.value.id).to eq user.id
  end

  it 'should not load user if one is set and current_user is false' do
    IgnoreCurrentUserExampleWorker.perform_async
    expect(IgnoreCurrentUserExampleWorker.value).to be_nil
  end
end