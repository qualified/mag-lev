module MagLev
  module Serialization
    class HashSerializer < Serializer
      def type
        @type ||= model.delete('_type') || model.delete(:_type)
      end

      def set_type
        builder.set!(:$type, type) if type
      end

      def build
        set_type
        builder.extract!(model, *model.keys)
      end
    end
  end
end
