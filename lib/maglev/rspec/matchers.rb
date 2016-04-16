require 'rspec/expectations'

RSpec::Matchers.define :broadcast do |expected|
  match do |proc|
    previous = MagLev.broadcaster.broadcasted.dup
    proc.call
    current = MagLev.broadcaster.broadcasted - previous
    count = current.select do |e|
      e.name == expected && (!@to || (@to & e.targets).size == @to.size)
    end

    if @times
      count.size == @times
    else
      count.any?
    end
  end

  chain :once do
    @times = 1
  end

  chain :twice do
    @times = 2
  end

  chain :times do |times|
    @times = times
  end

  chain :to do |*to|
    @to = to
  end

  failure_message do |actual|
    times = if @times.nil?
      "at least once"
    elsif times == 1
      "one time"
    else
      "#{@times} times"
    end

    to = if @to
      " to #{@to.size == 1 ? @to.first : @to}"
    end

    "expected #{expected} to be broadcasted #{times}#{to}"
  end

  def supports_block_expectations?
    true
  end
end