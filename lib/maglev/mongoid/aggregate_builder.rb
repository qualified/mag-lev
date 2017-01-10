module MagLev
  module Mongoid
    # Makes it easier to build aggregation framework queries for Mongoid.
    class AggregateBuilder
      attr_reader :commands

      def initialize(klass)
        @klass = klass
        @commands = []
      end

      # Set to true if the query should be scoped to the _type value of the class, useful for when you wish to aggregate
      # subclassed models
      def match_by_type(type)
        type = @klass.name if type == true
        commands << {"$match" => { "_type" => type }} if type
        self
      end

      # creates a new group step with the provided query. The id provided will be set as the "_id" value of the query.
      # If the query is nil then the step will be ignored, allowing you to easily chain optional logic together.
      def group(id, query)
        if query
          query['_id'] = "$#{id}"
          commands << {"$group" => query}
        end
        self
      end

      # creates a new match step with the provided query. If the query is nil then nothing will be inclued
      # @param [Hash] query Match query
      def match(query)
        commands << {"$match" => query} if query
        self
      end

      def match_eq(field, value)
        match({ field.to_s => value })
      end

      def match_ne(field, value)
        match({ field.to_s => { "$ne" => value }})
      end

      def match_gt(field, value)
        match({ field.to_s => { "$gt" => value }})
      end

      def match_gte(field, value)
        match({ field.to_s => { "$gte" => value }})
      end

      def match_lt(field, value)
        match({ field.to_s => { "$lt" => value }})
      end

      def match_lte(field, value)
        match({ field.to_s => { "$lte" => value }})
      end

      def match_in(field, *value)
        match({ field.to_s => { "$in" => value }})
      end

      def match_nin(field, *value)
        match({ field.to_s => { "$nin" => value }})
      end

      def limit(limit = nil)
        commands << {"$limit" => limit || 100000 }
        self
      end

      def results
        @results ||= @klass.collection.aggregate(commands)
      end

      def to_h
        @hash ||= {}.tap do |hash|
          results.each do |result|
            id = result.delete('_id')
            if result.keys.count == 1
              hash[id] = result.first.last
            else
              hash[id] = result
            end
          end
        end
      end
    end
  end
end