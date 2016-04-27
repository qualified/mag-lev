module MagLev
  module ActiveJob
    module Listeners
      extend ActiveSupport::Concern

      included do
        extended_option :listeners

        before_enqueue do
          # if globally enabled cool
          if Broadcaster.instance.enabled?
            # if inherit is set then that indicates that we should use the existing set of listeners instead
            # of assuming the defaults on the sidekiq server
            if extended_options['listeners'] == :inherit
              extended_options['listeners'] = Broadcaster.instance.listeners.map {|l| l.class.name }
            end
          end
        end

        around_perform do |_, block|
          # only perform this logic if listeners are enabled and this job was actually sent to the queue
          if MagLev.config.listeners.enabled and serialized?
            config = extended_options['listeners']
            if config.is_a? Array
              MagLev.broadcaster.only(*config.map {|l| Object.const_get(l)}) do
                block.call
              end

              # if config is false or the value was left as inherit by the client middleware,
              # then we are not supposed to use listeners
            elsif config == false or config == 'inherit'
              MagLev.broadcaster.disable! do
                block.call
              end

              if config == 'inherit'
                Rails.logger.info 'Event dispatch is disabled due to the server inheriting a disabled dispatcher'
              end
            else
              block.call
            end
          else
            block.call
          end
        end
      end
    end
  end
end