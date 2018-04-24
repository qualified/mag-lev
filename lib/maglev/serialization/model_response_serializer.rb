module MagLev
  class ModelResponseSerializer < Serializer
    attr_reader :builder, :total_count

    def build
      if model
        if model.is_a? Class
          @model_class = model
          build_class
        elsif model.is_a? Hash
          build_hash
        elsif model.respond_to?(:each)
          build_array
          meta_pagination
        else
          @model_class = model.class
          build_single
        end

        builder.meta do
          builder.timestamp Time.now
          builder.includes includes_param
        end
      end
    end

    protected

    def build_class
    end

    def build_hash
      builder.type(model[:_type] || 'Object')
      builder.data(partial(model, @options[:custom_serializer] || HashSerializer))
    end

    def build_array
      data = model.to_a
      if data.any?
        if data.first.is_a?(Hash)
          builder.type('Object')
          builder.data(array(data, @options[:custom_serializer] || HashSerializer))
        else
          builder.type(data.first.class.name)
          builder.data(array(data, @options[:custom_serializer]))
        end
      else
        builder.data []
      end
    end

    def meta_pagination
      # provide meta data for pagination
      if model.respond_to?(:current_page)
        builder.current_page(model.current_page)
        builder.total_pages(model.total_pages)
        builder.total_count(@total_count = model.total_count)
      end
    end

    def build_single
      builder.type model.class.name
      builder.data(partial(model, @options[:custom_serializer]))
    end
  end
end
