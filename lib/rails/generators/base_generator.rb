module MagLev
  class BaseGenerator < Rails::Generators::NamedBase
    protected

    def class_parts
      @class_parts ||= class_name.split('::')
    end

    def namespace_parts
      class_parts[0..-2]
    end

    def namespace_class
      namespace_parts.join('::')
    end
  end
end
