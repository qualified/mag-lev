$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rspec/core'
require 'rspec/mocks'
require 'rspec/its'
require 'redis'
require 'maglev'
require 'maglev/rspec'
require File.expand_path('../support/models', __FILE__)

MagLev::Rspec.configure