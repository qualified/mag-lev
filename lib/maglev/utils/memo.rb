# simple little helper to memoize values. Better than @name ||= because it can handle boolean values properly
# Adapted from https://github.com/hosh/rlet
module MagLev
  module Memo
    extend ActiveSupport::Concern

    # # instance version, which allows you to define a traditional method (much easier to navigate code structure using code tools)
    # # and then juse use memo from within the method body.
    # # i.e.
    # #    def foo
    # #       memo(:foo) { 1 + 1 }
    # #    end
    def memo(name, &block)
      @__memoized ||= {}
      if @__memoized.key?(name)
        @__memoized[name]
      else
        @__memoized[name] = block.call
      end
    end

    module ClassMethods
      # will update an existing method to be lazy evaluated
      def memo(name)
        unbound = instance_method(name)

        # if the method takes no arguments then we do not need to cache based off of arguments, so use a faster lookup
        if unbound.arity == 0
          define_method(name) do
            __memoized.fetch(name) { __memoized[name] = unbound.bind(self).call }
          end
        else
          define_method(name) do |*args|
            store = __memoized[name] ||= {}
            store.fetch(args) { store[args] = unbound.bind(self).call(*args) }
          end
        end
        name
      end
    end

    # clears the memo value so that the next call to the memorized method will re-evaluate its block
    def clear_memo(name)
      __memoized.delete(name)
    end

    private

    def __memoized
      @__memoized ||= {}
    end
  end
end
