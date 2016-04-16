module MagLev
  module Sidekiq
    module Serialization
      def self.deserialize_args(args, msg = {})
        args.map do |arg|
          if arg.is_a?(Hash)
            case arg['_']
              when '__gid'
                ::GlobalID::Locator.locate(arg['value'])
              when '__yaml'
                YAML.load(arg['value'])
              when '__destroyed'
                load_destroyed(arg)
              else
                arg
            end
          # HOTFIX/SUPER HACK: have yet to figure out why models are not being serialized properly with GlobalID
          # so this is here to pickup formats like this <Candidate:565f30e4240c8f0016000257>.
          # NOTE: this issue only happens sporadically with CRON scheduled workers, which always use root
          # level documents - so this hack is relatively safe. However this needs to be fixed properly ASAP
          elsif arg.is_a?(String) and msg['globalid'] and (arg =~ /<\w*:\w{24}>/) == 0
            arg.gsub(/<?(:\w{24}>)?/, '').to_const.find(arg.gsub(/(<\w*:)?>?/, ''))
          else
            arg
          end
        end
      end

      # special loader for loading destroyed models
      def self.load_destroyed(arg)
        klass = arg['class'].constantize
        attributes = JSON.load(arg['value'])

        # if the class has its own load method
        if klass.respond_to?(:load_destroyed)
          klass.load_destroyed(attributes)
        # otherwise use a basic implementation
        else
          klass.new(attributes).tap do |instance|
            instance.instance_variable_set('@destroyed', true)
          end
        end
      end

      class Server
        def call(worker_class, msg, queue)
          begin
            msg['args'] = Serialization.deserialize_args(msg['args'], msg)
          rescue => ex
            MagLev.logger.info msg.except('args')
            raise
          end
          yield
        end
      end
    end
  end
end
