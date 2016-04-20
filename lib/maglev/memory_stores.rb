module MagLev
  # for caching different types of things in memory when distributed caching is needed. You can use multiple stores
  # to act as namespaces. This can be very useful for when you have data that does not change often, such as configuration
  # data that is stored within the database. You can still set expirations so that eventually the system will pick
  # up any new changes.
  module MemoryStores
    @stores = {}
    @mutex = Mutex.new

    # gets a memory store by name, lazily creating a new one if it does not yet exist. This call is thread safe.
    def self.get(name, options = nil)
      @mutex.synchronize do
        @stores[name] ||= Store.new(options)
      end
    end

    def self.clear
      @mutex.synchronize do
        @stores.values.each(&:clear)
      end
    end

    # streamlined version of a memory cache store, with our own tweaked version of fetch
    class Store
      attr_reader :cache

      def initialize(options = {})
        @cache = ActiveSupport::Cache::MemoryStore.new(options)
      end

      def clear
        @cache.clear
      end

      def write(key, value)
        @cache.write(key, value)
      end

      # this streamlined version of fetch will run the block if nil is cached, unlike
      # the normal implemention which will cache nil and return it without calling the block
      def fetch(key, force: false)
        if force
          value = yield if block_given?
          write(key, value) if value
        else
          value = @cache.read(key)
          unless value
            value = yield if block_given?
            @cache.write(key, value) if value
          end
        end
        value
      end
    end
  end

end
