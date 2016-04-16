module MagLev
  module Sidekiq
    module Serialization

      class Client
        STANDARD_TYPES = [ NilClass, Fixnum, Float, String, TrueClass, FalseClass, Bignum ]

        def call(worker_class, msg, queue, redis_pool)
          msg['args'].map! do |arg|
            case arg
              when *STANDARD_TYPES
                arg
              else
                if arg.respond_to?(:to_global_id) and msg['globalid'] == true
                  if arg.respond_to?(:destroyed?) and arg.destroyed?
                    destroyed(msg, arg)
                  else
                    global_id(msg, arg)
                  end
                else
                  yaml(msg, arg)
                end
            end
          end

          yield
        end

        def destroyed(msg, arg)
          {'_' => '__destroyed', 'value' => arg.attributes.to_json, 'class' => arg.class.name }
        end

        def global_id(msg, arg)
          {'_' => '__gid', 'value' => arg.to_global_id(app: 'sidekiq').to_s}
        end

        def yaml(msg, arg)
          if MagLev.config.sidekiq.yaml_enabled and msg['yaml'] == true
            yml = YAML.dump(arg)
            # remove Procs, as that will break something for sure
            yml = yml.lines.reject {|l| l.include?('!ruby/object:Proc') }.join('')
            {'_' => '__yaml', 'value' => yml, 'id' => arg.to_s }
          else
            arg
          end
        end
      end
    end
  end
end
