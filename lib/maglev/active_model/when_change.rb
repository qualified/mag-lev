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

        def add_callback(callback, method = nil, &block)
          raise "from must be specified" if @from_values.nil?
          raise "to must be specified" if @to_values.nil?

          from_values = @from_values
          to_values = @to_values
          field = @field
          running = @running

          @klass.send(callback) do
            from = self.send("#{field}_was")
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
                      if method
                        self.send(method)
                      else
                        instance_exec(from, to, &block)
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