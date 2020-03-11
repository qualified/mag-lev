module MagLev
  module ActiveJob
    module Listeners
      extend ActiveSupport::Concern

      included do
        extended_option :listeners

        before_enqueue do
          # if globally enabled cool
          if Broadcaster.instance.enabled?
            # if inherit is set and the defaults are not in scope, then attach them now so we know exactly which ones to use.
            # If default listeners are being used, we won't attach so as to not take up uneeded space.
            if extended_options['listeners'] == :inherit and !Broadcaster.instance.default_listeners?
              extended_options['listeners'] = Broadcaster.instance.listener_names.to_a
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
            elsif config == false
              MagLev.broadcaster.suspend do
                block.call
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