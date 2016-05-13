require 'spec_helper'


class CurrentUserJob < MagLev::ActiveJob::Base

  def perform
    CurrentUserJob.user = User.current
  end

  cattr_accessor :user
end

describe MagLev::ActiveJob::CurrentUser do
  let(:user) { User.create }
  before do
    MagLev.configure do |config|
      config.current_user_class = :User
    end
    user.make_current
    CurrentUserJob.user = nil
  end

  let(:job) { CurrentUserJob.new }


  it 'should track current user if enabled' do
    CurrentUserJob.set(current_user: true, unique: false).perform_later
    expect(CurrentUserJob.user).to_not be_nil
    expect(CurrentUserJob.user.id).to eq user.id
  end

  it 'should not track current user if disabled' do
    CurrentUserJob.user = user
    CurrentUserJob.set(current_user: false, unique: false).perform_later
    expect(CurrentUserJob.user).to be_nil

    # double check that the current user was actually restored properly
    expect(User.current).to eq user
  end

  it 'should not track current user by default' do
    CurrentUserJob.user = user
    CurrentUserJob.perform_later
    expect(CurrentUserJob.user).to be_nil
  end
end