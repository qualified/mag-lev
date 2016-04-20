module MagLev
  module ActiveJob
    module Serialization
      extend ActiveSupport::Concern

      def global_id_enabled?
        @global_id_enabled = MagLev.config.active_job.global_id_enabled if @global_id_enabled.nil?
        @global_id_enabled
      end

      def yaml_enabled?
        @yaml_enabled = MagLev.config.active_job.yaml_enabled if @yaml_enabled.nil?
        @yaml_enabled
      end

      def serialize
        super.merge('globalid' => global_id_enabled?, 'yaml' => yaml_enabled?)
      end

      def deserialize(job_data)
        super
        @global_id_enabled = job_data['globalid']
        @yaml_enabled = job_data['yaml']
      end

      protected

      def serialize_arguments(arguments)
        arguments.map { |arg| serialize_argument(argument) }
      end

      def deserialize_arguments(arguments)
        arguments.map { |arg| deserialize_argument(argument) }
      end

      def serialize_argument(argument)

        case argument
          when *ActiveJob::Arguments::TYPE_WHITELIST
            argument
          when Array
            argument.map { |arg| serialize_argument(argument) }
          else
            if arg.respond_to?(:to_global_id) and global_id_enabled?
              if arg.respond_to?(:destroyed?) and arg.destroyed?
                destroyed(arg)
              else
                global_id(arg)
              end
            elsif yaml_enabled?
              yaml(arg)
            end
        end
      end

      def destroyed(arg)
        {'_' => '__destroyed', 'value' => arg.attributes.to_json, 'class' => arg.class.name }
      end

      def global_id(arg)
        app = MagLev.config.active_job.global_id_locator ? 'maglev' : GlobalID.app
        {'_' => '__gid', 'value' => arg.to_global_id(app: app).to_s}
      end

      def yaml(arg)
        if MagLev.config.sidekiq.yaml_enabled and msg['yaml'] == true
          yml = YAML.dump(arg)
          # remove Procs, as that will break something for sure
          yml = yml.lines.reject {|l| l.include?('!ruby/object:Proc') }.join('')
          {'_' => '__yaml', 'value' => yml, 'id' => arg.to_s }
        else
          arg
        end
      end

      def deserialize_argument(argument)
        # TODO
      end
    end
  end
end