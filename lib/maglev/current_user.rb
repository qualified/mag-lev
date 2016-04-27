# Code adapted from https://github.com/bokmann/sentient_user but uses RequestStore to be absolute sure
# that variables are not bleeding into other requests
module MagLev
  module CurrentUser
    def self.included(base)
      base.class_eval {
        def self.current
          current = MagLev.request_store[:user]
          if current.is_a? Proc
            current = MagLev.request_store[:user] = current.call
          end
          current
        end

        # returns the previous user, set when a do_as is called so that we can still access
        # the user who is really logged in. This value is only relevant with do_as, calling
        # `current = user` multiple times will not result in this value being set.
        def self.previous
          MagLev.request_store[:previous_user]
        end

        # sets the current user. A proc can be passed in if you wish to make the user lazy loaded
        def self.current=(user)
          unless user.is_a?(self) || user.nil? || user.is_a?(Proc)
            raise ArgumentError, "Expected an object of class '#{self}', got #{user.inspect}"
          end

          MagLev.request_store[:user] = user
        end

        def make_current
          MagLev.request_store[:user] = self
        end

        def current?
          !current.nil? && self.id == current.id
        end

        def self.do_as(user, &block)
          if self.current == user
            block.call
          else
            next_previous = self.previous
            MagLev.request_store[:previous_user] = previous = self.current

            begin
              self.current = user
              response = block.call
            ensure
              MagLev.request_store[:user] = previous
              MagLev.request_store[:previous_user] = next_previous
            end
          end

          response
        end
      }
    end
  end
end
