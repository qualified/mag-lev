module MagLev
  # A way to trap exceptions and log them in a way that doesnt cause the code to fail. This is
  # useful when you do want the surrounding code to be fault tolerant.
  # Typical Usage:
  #    Try.new(array).each {|v| v.save! }.raise_if_failures
  class Try
    # class TryRaisedError < RuntimeError
    #   attr_reader :try
    #   def initialize(try)
    #     @try = try
    #     super("#{try.failures.size} exceptions were raised")
    #   end
    # end

    class NoReuseError < RuntimeError
      def initialize
        super('Cannot reuse a Try instance')
      end
    end

    attr_reader :ok, :results, :target, :failures

    def initialize(target)
      @target = target
      @ok = []
      @results = []
      @failures = []
    end

    def failed_items
      failures.map(&:first).compact
    end

    def exceptions
      failures.map(&:last)
    end

    def catch(&block)
      raise NoReuseError if @used
      trap(target, &block)
      @used = true
      self
    end

    def each(&block)
      raise NoReuseError if @used
      to_a.each do |item|
        trap(item) do
          block.call(item)
        end
      end
      @used = true
      self
    end

    def map(&block)
      each(&block)
      results
    end

    # Calls the passed in block and then raises any errors. Useful for calling as a chain to the each method.
    def ensure(&block)
      raise "catch or each must be called before ensure" unless @used
      block.call
      raise_if_failures
    end

    # raises an exception if there were any failures
    def raise_if_failures
      raise exceptions.first if failures.any?
    end

    def to_a
      a = *target
    end

    protected

    def trap(item = nil)
      begin
        @results << yield
        @ok << item
      rescue => ex
        @results << nil
        failures << [item, ex]
        MagLev.logger.error(ex)

        # do not bother to log errors to rollbar if we are in the console
        unless defined?(Rails::Console) and Rails.env.development?
          # only log the first 10 exceptions to our error service in order to keep our service limits down
          MagLev::EventReporter.error(ex, item: item) unless failures.size > 10
        end
      end
    end
  end

end
