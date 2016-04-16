require 'spec_helper'
require File.expand_path('../../support/models', __FILE__)

describe MagLev::Event do
  let(:user) { User.new }
  subject(:event) { MagLev::Event.new(:user_created, user) }

end