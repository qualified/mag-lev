module MagLev
  module WhereFilters
    extend ActiveSupport::Concern

    def where_params
      @where_params = params[:where] ? JSON.parse(params[:where]) : {}
    end

    def apply_where_param(query, client_filters, default_where_params, &block)
      where = default_where_params.merge(where_params)
      deep_snake_case_params!(where)
      where.each do |field, filter|

        field = field.to_sym
        # if a block is given then we will use its value, unless
        if block_given?
          result = yield(query, field, filter)
          if result
            query = result
            next
          end
        end

        # custom filters allow maximum flexibility for creating your own filters. you can define a inline filter
        # within the class or use a symbol to point to an instance method.
        if custom_filter = self.class.where_field_filters[field]
          if custom_filter.is_a? Symbol
            query = self.send(custom_filter, query, field, filter)
          else
            query = self.instance_exec(query, filter, &custom_filter)
          end
          next
        end

        # client filters are used as a whitelist for allowing standard filter operations on existing fields to be performed.
        # admin users can use whatever filters they want, all other users must whitelist the allowed filters.
        unless client_filters.include?(field) or admin_logged_in?
          MagLev.logger.info("Skipping filter field #{field} since it is not allowed");
          next
        end

        # use the default where filter
        query = QueryUtils.where_filter(query, field, filter)
      end
      query
    end


    module ClassMethods

      def where_field_filters
        @where_field_filters ||= {}
      end

      def where_field_filter(field, method = nil, &block)
        raise "filter already defined for #{field}" if where_field_filters[field]
        where_field_filters[field] = block_given? ? block : method
      end

    end

  end
end
