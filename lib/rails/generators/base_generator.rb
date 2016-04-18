module MagLev
  class BaseGenerator < Rails::Generators::NamedBase
    protected

    def context_class_name
      @view_model_class_name ||= "#{model_class_name}::#{context_root}"
    end

    def model_class_name
      @controller_class_name ||= "#{model_namespaced? ? model_namespace + '::' : ''}#{model_root}"
    end

    def model_path_root(suffix = '', prefix = '')
      "#{model_namespaced? ? model_name + '/' : ''}#{prefix}#{model_root.underscore}#{suffix}"
    end

    def model_root
      (model_namespaced? ? class_parts[1] : class_parts[0])
    end

    def context_root
      class_parts.last
    end

    def model_namespace
      model_namespaced? ? class_parts.first : ''
    end

    def model_namespaced?
      class_parts.length > 2
    end

    def class_parts
      @class_parts ||= class_name.split('::')
    end

    def model_name
      @model_name ||= (model_namespaced? ? class_parts[1] : class_parts[0]).underscore
    end
  end
end
