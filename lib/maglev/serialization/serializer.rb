require 'active_support/core_ext/module/delegation'

module MagLev
  class Serializer
    attr_reader :model, :builder, :root, :params, :includer, :include_nil, :options

    delegate :includable_query, :includable?, :join_namespace,
             :includes_param, :meta_param, :list?, to: :includer

    def initialize(model, includer: nil, params: {}, namespace: '', include_nil: true, **options)
      @model = model
      @builder = Jbuilder.new(ignore_nil: !include_nil)
      @includer = includer || Includer.new(self)
      @params = HashWithIndifferentAccess.new(params)
      @namespace = namespace
      @include_nil = include_nil
      @options = options

      builder.id(id) if id
      build
    end

    def id
      @id ||= model.id.to_s if model.respond_to?(:id) and not model.is_a?(Hash)
    end

    def build
    end

    def to_json
      builder.target!
    end

    def to_hash
      builder.attributes!
    end

    def fields(*names, model: self.model, default: nil, camelize: false)
      names.each do |name|
        value = model.send(name)
        value = default unless value || value == false
        if value.is_a?(Float)
          value = default if value&.nan?
          value = default if value&.infinite?
        end

        name = name.to_s
        if value || value == false
          if name.ends_with?('_id') || name == 'id'
            value = value.to_s
          elsif name.ends_with?('_ids')
            value = value.map(&:to_s)
          end
        end

        value = convert_to_camel_keys(value) if camelize

        builder.set!(name, value)
      end
    end

    def convert_to_camel_keys(value)
      case value
      when Hash then value.deep_transform_keys {|key| key.to_s.camelize(:lower) }
      when Array then value.map {|v| convert_to_camel_keys(v) }
      else value
      end
    end

    # used to map a relation (either a collection or single item) and build its partial.
    # This method provides the includeable option as a convienence to having to wrap
    # relations within includable blocks.
    # The permission option is used to call `user_can!(permission)` - most useful for when
    # includable is used, since this enforcement will only be applied IF the inclusion was requested.
    # default can be passed in, which will be used in place of a missing value
    def relation(name, includable: false, serializer: nil, value: nil, allow_nil: false,
                 default: nil, permission: nil, order_by: nil, model: self.model, &block)

      current_pathname = join_namespace(@namespace, name)

      if includable
        # early return if this includable relationship wasn't requested
        return unless includable?(current_pathname)
        # early return if this includable relationship was cancelled by the lazy permission check
        return if block_given? and !block.call
      end

      user_can!(permission) if permission
      value ||= model.send(name) || default
      # allow a proc to be passed in, which can be used to lazy load the value
      if value.is_a?(Proc)
        value = value.arity > 0 ? value.call(model) : value.call
      end
      value = value.order_by(order_by) if order_by and value.respond_to?(:order_by)
      if value
        if value.respond_to?(:each)
          builder.set!(name, array(value, serializer, current_pathname))
        else
          builder.set!(name, partial(value, serializer, current_pathname))
        end
      elsif include_nil and allow_nil
        builder.set!(name, nil)
      end
    end

    def partial(partial_model, serializer = nil, current_pathname = '')
      partial_model = model.send(partial_model) if partial_model.is_a? Symbol
      serializer = Serializer.from_model(partial_model) if serializer.nil?
      serializer = Serializer.from_name(serializer) if serializer.is_a? String

      instance = serializer.new(partial_model, includer: @includer, params: @params,
                                namespace: current_pathname, include_nil: include_nil, **@options)
      instance.to_hash
    end

    def array(models, serializer = nil, current_pathname = '')
      serializer = Serializer.from_name(serializer) if serializer.is_a? String
      models.map {|m| partial(m, serializer, current_pathname) }
    end

    def self.from_model(model)
      from_name(model.class.name)
    end

    def self.from_name(name)
      "#{name}Serializer".to_const
    end

    class Includer
      attr_reader :root

      def initialize(root)
        @root = root
      end

      # returns true if the root model is a list
      def list?
        root.model.respond_to?(:each)
      end

      def params
        root.params
      end

      # eager loads a query if the item is going to be be included. Currently this method
      # only supports including one relation
      def includable_query(name, query)
        if includes_param.include?(name) and includable?(name)
          query.includes(name)
        else
          query
        end
      end

      def join_namespace(namespace, name)
        namespace.empty? ? name : "#{namespace}.#{name}"
      end

      def includable?(name)
        includes_param.include?(name.to_sym)
      end

      # returns the include param, always as an array
      def includes_param
        @includes_param ||= begin
          param = *params[:includes]
          param.map(&:to_sym)
        end
      end

      def meta_param
        @meta_param ||= begin
          param = *params[:meta]
          param.map(&:to_sym)
        end
      end
    end
  end
end
