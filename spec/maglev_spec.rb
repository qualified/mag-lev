require 'spec_helper'

describe MagLev do
  it 'has a version number' do
    expect(MagLev::VERSION).not_to be nil
  end

  describe '.redis' do
    it 'yields a memoized client when Sidekiq is not available' do
      clients = 2.times.map { MagLev.redis { |r| r } }
      expect(clients.first).to be_a(Redis)
      expect(clients.first).to equal(clients.last)
      expect(MagLev.redis { |r| r.ping }).to eq 'PONG'
    end
  end
end
