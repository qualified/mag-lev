require 'spec_helper'

describe MagLev do
  it 'should have a configure method' do
    expect(MagLev).to respond_to :configure
  end

  describe 'listeners' do
  end

  describe 'current_user' do
    before do
      MagLev.configure do |config|
        config.current_user_class = :User
      end
    end

    it 'should add CurrentUser to User' do
      expect(User).to respond_to :current
    end
  end
end