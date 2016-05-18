module MagLev
  module ActiveJob
    # small adapter which provides a on_perform method so that
    # arguments do not need to be specified, and also ensures that
    # self is always returned by a perform_now/perform call
    class ServiceObject < MagLev::ActiveJob::Base
      include MagLev::ActiveJob::Arguments

      def enqueued?
        !!@enqueued
      end

      def performed?
        !!@performed
      end

      after_enqueue do
        @enqueued = true
      end

      around_perform do |_, block|
        raise "already performed" if performed?
        EventReporter.with_context(self.class.name, self.arguments) do
          begin
            block.call
          ensure
            @performed = true
          end
        end
      end

      protected

      def perform(*)
        on_perform
        self
      end

      def on_perform
        fail NotImplementedError
      end
    end
  end
end