module MagLev
  module Mongoid
    # will convert a mongoid criteria object into an elastic query result. The elastic query result can then
    # of course also be converted back into a mongoid criteria once ES has been queried (using ids instead of conditions).
    class ElasticQuery
      include Elasticsearch::DSL

      attr_reader :criteria
      attr_accessor :aggregate_fields

      def initialize(criteria, aggregate_fields = nil)
        @criteria = criteria.dup
        @aggregate_fields = *aggregate_fields
      end

      def response
        @response ||= klass.search(definition)
      end

      def to_a
        response.records.to_a
      end

      def each(&block)
        response.records.each(&block)
      end

      def klass
        criteria.klass
      end

      # this tracks which fields were actually mapped into the ES query. Useful because not all
      # mongoid conditions are supported, and any that are not can later be reaplied as a mongoid query
      # once ES has been queried.
      def query_fields
        @query_fields ||= []
      end

      def aggregation_counts
        if response.aggregations
          @aggregation_values ||= response.aggregations.to_h.transform_values do |key, value|
            groups = value.buckets.map {|h| [h[:key], h.doc_count] }
            Hash[*groups.flatten]
          end
        end
      end

      def definition
        @definition ||= Hashie::Mash.new.tap do |m|
          if criteria.selector.present?
            criteria.selector.each do |field, conditions|
              query_fields << field if build_conditions(field, conditions)
            end

            m.query = {bool: bool} if bool.present?
          end

          m.aggs = aggregations if aggregations

          m.size = limit if limit
          m.from = skip if skip
          if criteria.options[:sort]
            m.sort = criteria.options[:sort].map do |key, value|
              {key => value == 1 ? 'asc' : 'desc'}
            end
          end
        end.to_hash
      end

      def aggregations
        if aggregate_fields
          @aggregations ||= {}.tap do |h|
            aggregate_fields.each do |field|
              h[field] = { terms: { field: field }}
            end
          end
        end
      end

      def bool
        @bool ||= {
          "must" => must.presence,
          "must_not" => must_not.presence,
          "filter" => filter.presence,
          "should" => should.presence
        }.compact
      end

      def filter
        @filter ||= []
      end

      def must
        @must ||= []
      end

      def must_not
        @must_not ||= []
      end

      def should
        @should ||= []
      end

      def limit
        criteria.options[:limit] || 100
      end

      def skip
        criteria.options[:skip] || 0
      end

      def total_count
        response.results.total
      end

      def total_pages
        total_count / 100 + 1
      end

      def current_page
        skip / limit + 1
      end

      protected

      # builds ES query clauses out of mongoid conditions. Not all conditions are mapped. True will be
      # returned if a field was fully mapped
      def build_conditions(field, conditions, negated = false)
        if field == '$or'
          build_or_matchers(conditions)
        else
          case conditions
            when String, BSON::ObjectId, Symbol
              build_string_condition(field, conditions.to_s, negated)
            when Regexp
              build_regexp_condition(field, conditions, negated)
            when nil
              build_nil_condition(field, conditions, negated)
            when Array
              build_terms_match(field, conditions, negated)
            when Integer, true, false
              build_term_match(field, conditions, negated)
            when Hash
              type, value = conditions.first
              case type
                when '$ne' then build_conditions(field, conditions.first.last, true)
                when '$in' then build_terms_match(field, value, false)
                when '$nin' then build_terms_match(field, value, true)
              end
          end
        end
      end

      def build_or_matchers(conditions)
        conditions.each do |selector|
          criteria = klass.all
          criteria.selector = selector
          eq = ElasticQuery.new(criteria)
          should.push(eq.definition['query'])
        end
      end

      def build_nil_condition(field, value, negated)
        (negated ? filter : must_not).push(exists: { field: field })
      end

      def build_term_match(field, value, negated)
        (negated ? must_not : filter).push(term: { field => value })
      end

      def build_terms_match(field, value, negated)
        (negated ? must_not : filter).push(terms: { field => value })
      end

      def build_multi_match(value, negated)
        (negated ? must_not : filter).push(multi_match: {
          query: value,
          fields: klass.multi_searchable.to_a
        })
      end

      def build_string_condition(field, value, negated)
        # if a string representation of a regex
        if /^\/.*\/i?$/ =~ value
          # gotta remove the regexp syntax from the string
          (negated ? must_not : must).push(regexp: { field => value.gsub(/^\/|\/i?$/, '') })
        elsif field == 'q'
          build_multi_match(value, negated)
        else
          build_term_match(field, value, negated)
        end
      end

      def build_regexp_condition(field, value, negated)
        # query.regexp = { field => conditions.to_s.gsub('(?i-mx:', '').gsub(/\)$/, '.*') }
        term = value.to_s.gsub('(?i-mx:', '').gsub(/\)$/, '')
        (negated ? must_not : filter).push(match_phrase_prefix: { field => { query:  term }})
      end
    end
  end
end