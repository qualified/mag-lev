module MagLev
  module ActiveJob
    # determines if the current user value should be handled while within the perform block.
    # If set to false, current user will be ignored both inprocess and when performed later.
    # If set to true, the inprocess current user value will be sent to the background where it will
    # be restored while the job executes.
    module CurrentUser
      extend ActiveSupport::Concern

      included do
        extended_option :current_user

        before_enqueue do
          if extended_options['current_user']
            if MagLev.config.current_user_class
              user = MagLev.config.current_user_class.current
              # if the user is set then pass the id in, otherwise set to nil to indicate it was not set to begin with
              extended_options['current_user'] = user ? user.id.to_s : nil
            else
              extended_options.delete('current_user')
            end
          end
        end

        before_perform do
          if extended_options['current_user'] and serialized?
            MagLev.config.current_user_class.current ||= Proc.new do
              MagLev.config.current_user_class.find(extended_options['current_user'])
            end
          end
        end

        around_perform do |_, block|
          if extended_options['current_user'] == false
            MagLev.config.current_user_class.do_as(nil, &block)
          else
            block.call
          end
        end
      end
    end
  end
end