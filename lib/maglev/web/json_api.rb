module MagLev
  module JsonApi
    extend ActiveSupport::Concern

    included do
      before_action :deep_snake_case_params!
      around_action :record_action_metrics

      rescue_from Mongoid::Errors::DocumentNotFound, with: :not_found!
      rescue_from Mongoid::Errors::Validations, with: :model_errors!
      rescue_from MagLev::ActiveModel::UnitOfWork::InvalidError, with: :model_errors!

      # FOR API DEBUGGING UN-COMMENT THIS OUT
      # unless Rails.env.development?
      rescue_from Mongoid::Errors::InvalidIncludes do
        bad_request! 'Invalid include parameter value was given'
      end

      rescue_from MagLev::InvalidStateError, with: :forbidden!
      rescue_from MagLev::InvalidDataError, with: :unprocessable_entity!
      rescue_from MagLev::Guard::Error, with: :unprocessable_entity!
      rescue_from MagLev::DuplicationError, with: :conflict!
      rescue_from ActionController::ParameterMissing, with: :bad_request!
      # end
    end

    protected

    # Configurable options for calling as_list. Since as_list can only be called once per controller instance, this
    # method makes it much easier to configure list options for specific api modes (admin, team, candidate).
    # Options Include:
    #   client_filters - a whitelist of which fields can be queried on. Default is [:state, :id]
    #   filters - allows you to customize which filters are applied (deprecated?)
    #   default_where_params - where params applied by default, can be overriden by the client
    #   default_order_by - if a specific order_by is not set for the request, this order by will be used. default is nil
    #   default_limit - if a per/limit param is not provided, then this sets the limit. Default is 1000
    #
    def list_options
      @list_options ||= Hashie::Mash.new(client_filters: [:state, :id], default_limit: 1000)
    end

    # applies common parameter information to list based queries, such as pagination, sorting and includes
    # an includes option can be passed in to limit the includes that should be passed into the query
    def as_list(query, options = nil, &block)
      list_options.merge!(options) if options

      query = query.page(params[:page])

      if params[:where] || list_options.default_where_params.present?
        query = apply_where_param(query, list_options.client_filters, list_options.default_where_params || {}, &block)
      end

      # apply include params to try to prevent n + 1 queries
      if includes_param.any?
        # only include the items that are includable within the query.
        includes = includes_param & model_root_includables(query)
        query = query.includes(*includes)
      end

      # TODO: this should be removed, replaced by query_filters
      unless list_options.filters.blank?
        list_options.filters.each do |filter|
          query = query.where(filter => params[filter]) if params[filter]
        end
      end

      if params[:skip]
        query = query.skip(params[:skip])
      end

      # if pagination is being used then we want to use the per value instead of limit
      if params[:per]
        query = query.per(params[:per])
      elsif !params[:page]
        query = query.limit(params[:limit] || list_options.default_limit)
      end

      # apply sorting (ie "first_name ASC")
      if params[:order_by]
        query = query.order_by(params[:order_by].underscore)
      elsif list_options.default_order_by
        query = query.order_by(list_options.default_order_by)
      end

      MagLev.logger.info(query)


    end

    # returns the includable relationships that are available for a given query. Override to support for a specific ORM
    def model_root_includables(query)
      @model_root_includables ||= {}
    end

    # returns the include param, always as an array
    def includes_param
      @includes_param ||= begin
        param = *params[:includes]
        param.map(&:to_sym)
      end
    end

    # convenience method that helps locate a param that could be either a root param or nested within :data.
    # This method is useful for when you have a shared model lookup method that is used by multiple CRUD actions.
    def find_param(*names)
      names.each do |name|
        param = params[name] || params[:data].try(:[], name)
        return param if param
      end
      nil
    end

    # enables the ability to include hash objects as params where the keys are dynamic. Returns a hash
    # with all of the dynamic hash keys defined for each param
    def dynamic_data_hash_params(*keys)
      data = params[:data]
      if data
        data.slice(*keys).transform_values! do |value|
          value.try(:keys)
        end
      else
        {}
      end
    end

    def data_params
      params.require(:data)
    end

    # returns the value of a particular data param. Does not raise an error if data param is not available
    def data_param(name)
      params.try(:[], 'data').try(:[], name)
    end

    # a wrapper method that renders resource within the json api model serializer
    def json_api(resource = nil, serializer: nil)
      serializer = defined?(ModelResponseSerializer) ? ModelResponseSerializer : MagLev::ModelResponseSerializer
      model_serializer = serializer.new(resource, params: params, custom_serializer: serializer)

      # some clients like to respond to total count headers (like ng-admin), so give them want they want
      response.headers['X-Total-Count'] = model_serializer.total_count if model_serializer.total_count
      render json: model_serializer.to_json
    end

    def forbidden!(reason = 'forbidden')
      MagLev::EventReporter.info("403: #{reason}")
      render_json_reason(reason, 403)
    end

    def overridable!(reason = 'admin only')
      MagLev::EventReporter.info("403: #{reason}")
      render_json_reason(reason, 403)
    end

    def unauthorized!(reason = 'unauthorized')
      MagLev::EventReporter.info("401: #{reason}")
      render_json_reason(reason, 401)
    end

    def locked!(reason = 'resource locked')
      MagLev::EventReporter.info("423: #{reason}")
      render_json_reason(reason, 423)
    end

    def not_found!
      MagLev::EventReporter.warn('404: Resource not found')
      render_json_reason('not found', 404)
    end

    def method_not_allowed!(reason = 'method not allowed')
      MagLev::EventReporter.warn("405: #{reason}")
      render_json_reason(reason, 405)
    end

    def bad_request!(reason = 'bad request')
      MagLev::EventReporter.warn("400: #{reason}")
      render_json_reason(reason, 400)
    end

    def conflict!(reason = 'Request would create duplicate information')
      MagLev::EventReporter.warn("409: #{reason}")
      render_json_reason(reason, 409)
    end

    def unprocessable_entity!(reason = 'unprocessable')
      MagLev::EventReporter.warn("422: #{reason}")
      render_json_reason(reason, 422)
    end

    def model_errors!(ex)
      model = ex.respond_to?(:document) ? ex.document : nil
      model ||= ex.respond_to?(:model) ? ex.model : nil
      model ||= ex.respond_to?(:attributes) ? ex : nil

      if model
        errors = model.respond_to?(:embedded_errors) ? model.embedded_errors : model.errors
        render json: {
        errors: errors,
        type: model.class.name,
        attributes: (model.attributes unless Rails.env.production?),
        id: model.id.to_s,
        reason: 'ValidationErrors'
        },
               status: 422
      else
        render json: { reason: 'DocumentErrors', type: ex.to_s },
               status: 422
      end
    end

    def render_json_reason(reason, status)
      reason = reason.message if reason.respond_to?(:message)
      json = {
      reason: reason,
      user: current_user ? current_user.name : nil
      }
      MagLev.logger.info(json)
      render json: json, status: status
    end

    # converts camel cased params to be snake cased instead.
    def deep_snake_case_params!(val = params)
      deep_convert_param_keys!(val) do |k|
        # convert _id to id, otherwise underscore any possible camel cased keys
        k == '_id' ? 'id' : k.underscore
      end
    end

    def deep_convert_param_keys!(val = params, &block)
      case val
        when Array
          val.map {|v| deep_convert_param_keys!(v, &block) }
        when Hash
          val.keys.each do |k, v = val[k]|
            val.delete k
            val[block.call(k)] = deep_convert_param_keys!(v, &block)
          end
          val
        else
          val
      end
    end

    def record_action_metrics(&block)
      MagLev::Statsd.perform("web.controller.#{self.class.name}.#{action_name}", &block)
    end
  end
end