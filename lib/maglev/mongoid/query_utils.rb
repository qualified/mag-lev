module MagLev
  module Mongoid
    module QueryUtils
      def self.aggregate_field_summary(klass, field, type: nil, limit: nil, all: false)
        if defined?(Mongoidal)
          # if they did not provide a type and this is not a root document,
          # supply the class as the type because the query will be run against the root doc's collection
          type ||= klass.to_s if ((klass.ancestors - [klass]) & Mongoidal::RootDocument.classes).any?
        end

        builder = AggregateBuilder.new(klass).match_by_type(type)

        builder = yield(builder) if block_given?

        results = builder
          .group(field, {"count" => { "$sum" =>1 }})
          .limit(limit)
          .to_h

        results[:all] = results.values.sum if all
        results
      end

      def self.aggregate_duplicates(klass, field, type: nil, limit: nil)
        AggregateBuilder.new(klass)
          .match_by_type(type)
          .match_ne(field, nil)
          .group(field, {"matches" => { "$sum" =>1 }, "ids" => { "$addToSet" => "$_id"}})
          .match_gte('matches', 2)
          .limit(limit)
          .to_h
      end

      # deletes any duplicates, returns the ids of the duplicate records that were kept (that are now unique).
      # you can match on a type by passing in type. You can keep either the first found or last found duplicate.
      def self.delete_duplicates(klass, field, type: nil, limit: nil, verbose: true, keep: :first)
        keepers = []
        results = aggregate_duplicates(klass, field, type: type, limit: limit)
        ids = []
        results.each do |id, dup|
          puts "Dup found for #{id}" if verbose
          dup_ids = dup['ids']
          keeper = dup_ids.send(keep)
          dup_ids.delete(keeper)
          dup_ids.each do |id|
            ids << id
          end
          keepers << keeper
        end

        puts "ids count = #{ids.size}" if verbose
        klass.in(id: ids).delete
        keepers
      end

      def self.search(query, field, value)
        query.where(field => /#{Regexp.escape(value)}/i)
      end

      # returns ids of documents for a given field, using a regex to search the entire value
      def self.search_ids(query, field, value)
        search(query, field, value).pluck(:id)
      end

      def self.where_filter(query, field, filter)
        # support shortcut syntax
        if filter.is_a? Array
          query.in(field => filter)
        elsif filter.is_a? Hash
          filter = filter.first
          val = filter.last
          case filter.first
            when '==', '==='
              query = query.where(field => val)
            when '!=', '!=='
              query = query.ne(field => val)
            when '>='
              query = query.gte(field => val)
            when '>'
              query = query.gt(field => val)
            when '<='
              query = query.lte(field => val)
            when '<'
              query = query.lt(field => val)
            when 'contains'
              query = query.where(field => /#{Regexp.escape(val)}/i)
            when 'not_contains'
              query = query.not.where(field => /#{Regexp.escape(val)}/i)
            when 'in'
              query = query.in(field => val)
            when 'not_in'
             query = query.nin(field => val)
            # special Mongoid filter, used to reference a scope. True will use the scope, false will use not.scope
            # NOTE: only works at the top level, you can not access nested model scopes
            when 'scope'
              query = filter.last ? query.send(field) : query.not.send(field)
            else
              raise MagLev::InvalidDataError.new("where parameter #{filter.first} is not supported")
          end
        else
          query = query.where(field => filter)
        end
      end
    end
  end
end