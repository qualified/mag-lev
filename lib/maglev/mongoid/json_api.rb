module MagLev
  module Mongoid
    module JsonApi
      extend ActiveSupport::Concern

      included do
        include MagLev::JsonApi
        include WhereFilters
      end

      protected

      # applies common parameter information to list based queries, such as pagination, sorting and includes
      # an includes option can be passed in to limit the includes that should be passed into the query
      def as_list(query, options = nil, &block)
        query = super

        # if a general search query or aggrigate counts were requested, then use elastic search
        if params[:q] || params[:field_counts]
          ElasticQuery.new(query, params[:field_counts])
        else
          query
        end
      end

      # returns the includable relationships that are available for a given query
      def model_root_includables(query)
        @model_root_includables ||= {}
        @model_root_includables[query.klass.name] ||= query.klass.relations.select do |k, v|
          [:has_many, :has_one, :belongs_to].include? v.macro
        end.keys.map(&:to_sym)
      end
    end
  end
end