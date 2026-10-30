require 'active_support'

module MagLev
  module ActiveModel
    # extends active model based records with the ability to manage data state flow
    module WhenChange
      extend ActiveSupport::Concern

      # allows you to bypass "protected" code
      def unprotected(&block)
        begin
          @unprotected = true
          block.call
        ensure
          @unprotected = false
        end
      end

      def unprotected?
        @unprotected
      end

      def protected?
        !@unprotected
      end

      module ClassMethods
        def when_change(field)
          WhenTransition.new(self, field)
        end
      end

      class WhenTransition
        def initialize(klass, field)
          @klass = klass
          @field = field
          @running = {}
        end

        def from(*values)
          @from_values = values
          @to_values = nil
          self
        end

        def from_any
          @from_values = :*
          @to_values = nil
          self
        end

        def to(*values)
          @to_values = values
          self
        end

        def to_any
          @to_values = :*
          self
        end

        [:before_save, :after_save, :before_update, :after_update, :before_create, :after_create,
        :before_validation, :after_initialize].each do |callback|
          define_method callback do |method = nil, &block|
            add_callback(callback, method, &block)
          end
        end

        # will add a validation message if the from/to states match
        def invalidate(msg = nil, &block)
          field = @field
          add_callback(:validate) do |from, to|
            if block
              msg = instance_exec(from, to, &block)
              if msg
                self.errors[field] << msg
              end
            else
              self.errors[field] << msg || 'is an invalid'
            end
          end
        end

        # this callback is ran before_save unless it is called inside of a "unprotected" block
        def protect(callback = :before_save, &block)
          add_callback(callback) do |from, to|
            unless @unprotected
              instance_exec(from, to, &block)
            end
          end
        end

        # Mongoid ignores `attribute_was` inside after_* callbacks, so remember the persisted value in
        # before_save. A save made from inside one of our callback blocks (depth > 0) must not overwrite
        # it, or the callbacks that run after it would see from == to.
        def capture_from_value(field)
          captured = (@klass.instance_variable_get(:@_maglev_captured_fields) || @klass.instance_variable_set(:@_maglev_captured_fields, []))
          return if captured.include?(field)

          captured << field
          @klass.before_save(prepend: true) do
            @_maglev_from_values ||= {}
            @_maglev_from_values[field] = self.send("#{field}_was") unless @_maglev_depth.to_i > 0
          end
        end

        def add_callback(callback, method = nil, &block)
          raise "from must be specified" if @from_values.nil?
          raise "to must be specified" if @to_values.nil?

          from_values = @from_values
          to_values = @to_values
          field = @field
          running = @running
          after_callback = [:after_save, :after_update, :after_create].include?(callback)
          capture_from_value(field) if after_callback

          @klass.send(callback) do
            # Mongoid 8 makes `attribute_was` return the new value inside after_* callbacks, so use
            # the value captured in before_save.
            from =
              if after_callback && @_maglev_from_values&.key?(field)
                @_maglev_from_values[field]
              else
                self.send("#{field}_was")
              end
            to = self.send(field)

            # collect a hash to identify the uniqueness of this callback
            hash = [from_values, to_values, from, to, field, callback].hash

            # only run this callback once per cycle
            unless running[hash]
              running[hash] = true
              begin
                if from != to
                  if from_values == :* || from_values.include?(from)
                    if to_values == :* || to_values.include?(to)
                      @_maglev_depth = @_maglev_depth.to_i + 1
                      begin
                        if method
                          self.send(method)
                        else
                          instance_exec(from, to, &block)
                        end
                      ensure
                        @_maglev_depth -= 1
                      end
                    end
                  end
                end
              ensure
                running[hash] = false
              end
            end
          end
          self
        end
      end
    end
  end
end