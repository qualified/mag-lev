module MagLev
  module ElasticSearch
    module Searchable
      extend ActiveSupport::Concern
      include MagLev::ActiveJob::DeferredMethods

      # takes a hash and converts any nested BSON::ObjectId values into strings
      def self.map_bson(data)
        data.map do |k, v|
          case v
            when BSON::ObjectId
              [k == '_id' ? 'id' : k, v.to_s]

            when Array
              [k, v.map do |m|
                if m.is_a? Hash
                  Searchable.map_bson(m)
                else
                  m.is_a?(BSON::ObjectId) ? m.to_s : m
                end
              end]

            when Hash
              [k, Searchable.map_bson(v)]

            else
              [k == '_type' ? 'class_type' : k, v]
          end
        end.to_h
      end

      included do
        include Elasticsearch::Model

        index_name "q_#{self.name.downcase.pluralize}__#{Rails.env}"
      end

      # reindexes the document, causing it to be inserted, updated or destroyed as needed.
      # If an existing document has changes, its changed fields will be updated only, unless true is passed in
      def reindex(force = false)
        if destroyed?
          __elasticsearch__.delete_document rescue nil

        elsif should_index?
          if new_record? || !changed? || force
          __elasticsearch__.index_document
          else
            __elasticsearch__.update_document rescue __elasticsearch__.index_document
          end
        end
        self
      end

      def should_index?
        true
      end

      # returns the already indexed data from elastic search
      def as_indexed
        self.class.search("id: #{id}").first
      end

      # adds the ability to support the bson option, will will map the _id: BSON::ObjectId value to be id: string.
      # this mapping happens on a deep level. The option is needed for indexing within ES.
      def as_json(options = {})
        if options[:bson]
          Searchable.map_bson(super)
        else
          super
        end
      end

      def default_indexed_field_names
        self.class.fields.keys
      end

      # used by elastic search. This method is extended to automatically include only
      # defined field names, as well as supports automatic inclusion of embedded data.
      # references can be passed in which is an array of relations. as_referenced_json will
      # be called on each referenced relation if it is available on the model.
      def as_indexed_json(options = {})
        except = options[:except] || []
        except = [except] unless except.is_a?(Array)
        options[:only] ||= default_indexed_field_names - except.map(&:to_s)
        options[:references] ||= self.class.indexed_references

        Searchable.map_bson(
          as_json(options).tap do |json|
            references = (options[:references] || []).map(&:to_s)
            # special case to include embedded data or optional "reference" data
            relations.each do |name, config|
              if references.include?(name)
                data = index_referenced_json(self.send(name))
                if data
                  data.compact!
                  json[name] = data if data.present?
                end
              end
            end
          end
        )
      end

      protected

      def index_referenced_json(item)
        if item.is_a?(Array)
          item.map {|i| index_referenced_json(i) }
        elsif item.respond_to?(:as_referenced_json)
          item.as_referenced_json
        else
          item.as_json(except: :id)
        end
      end

      module ClassMethods
        # ElasticSearch::Model doesn't support single index inheritence so we need to fake it
        def inherited(subclass)
          search_class = self.search_class
          index_name = self.index_name
          document_type = self.document_type

          subclass.instance_eval do
            @search_class = search_class
            index_name(index_name)
            document_type(document_type)

            def self.mapping(*args, &block)
              search_class.mapping(*args, &block)
            end

            def self.index_references(*args)
              search_class._index_references(self, *args)
            end

            def self.indexed_references
              search_class.indexed_references
            end

            def self.multi_searchable(*fields)
              search_class.multi_searchable(fields)
            end
          end

          super
        end

        def search_class
          @search_class || self
        end

        def delete_index!
          __elasticsearch__.delete_index!(force: true)
        end

        def recreate_index!
          __elasticsearch__.delete_index!(force: true) rescue nil
          create_index!
        end

        def ensure_index
          Rails.logger.info "Ensuring index for #{self.name}"
          create_index! unless __elasticsearch__.index_exists?
        end

        def refresh_index!
          __elasticsearch__.refresh_index!(force: true)
        end

        # rebuilds the index one by one, without first recreating it. useful if you want to make sure
        # missing records are added to the index but there are no mapping updates
        def reindex(deferred = false)
          all.each do |record|
            begin
              deferred ? record.deferred.reindex : record.reindex
            rescue => ex
              Rails.logger.error("Failed to index #{record.id}")
              Rails.logger.error(ex)
            end
          end
        end

        # rebuilds the index from scratch.
        # safe option is slow, but will catch errors while serializing/indexing each individual record
        def reset_index!(safe = false)
          recreate_index!

          if safe || !respond_to?(:import)
            reindex(safe == :deferred)
          else
            import
          end
        end

        def embedded_relation_names
          relations.select {|n, c| c.macro.to_s.starts_with?("embeds_")}.map(&:first)
        end

        attr_reader :indexed_references

        # called to setup index references & nested type indexes. additional references can be passed in
        # embed references are automatically included
        def index_references(*references)
          _index_references(self, *references)
        end

        # private version which allows you to pass in a reference class to pull relations from
        def _index_references(klass, *references)
          @nested_index_types ||= []
          @indexed_references ||= Set.new(embedded_relation_names)
          @indexed_references += references.map(&:to_s)

          @indexed_references.each do |reference|
            if !@nested_index_types.include?(reference)
              relation = klass.relations[reference]
              if !relation
                Rails.logger.warn "Searchable: Relation #{reference} does not exist for #{name}"
              elsif relation.macro.to_s.ends_with?("_many")
                @nested_index_types << reference
                mapping { indexes reference, type: 'nested' }
              end
            end
          end
        end

        # defines a default template to use for dynamically added string values. Will cause all strings to not be analyized by default
        # unless they are suffixed with _analyzed
        def string_index_template
          {
            match_mapping_type: "string",
            unmatch: "*.analyzed",
            mapping: {type: "string", index: "not_analyzed"}
          }
        end

        def dynamic_templates
          @dynamic_templates ||= [{strings: string_index_template}]
        end

        # extends the default es mapping feature to include dynamic templates
        def index_mappings
          self.mappings.to_hash.tap do |mappings|
            mappings.values.first[:dynamic_templates] = dynamic_templates
          end
        end

        def create_index!
          raise "Cannot call create_index! on embedded collection" if is_a?(Mongoidal::EmbeddedDocument)

          es = __elasticsearch__
          unless es.index_exists?
            es.client.indices.create index: es.index_name, body: {
              settings: es.settings.to_hash,
              mappings: index_mappings
            }
          end
        end

        def multi_searchable(*fields)
          @multi_searchable ||= Set.new
          @multi_searchable += fields.map(&:to_s).select(&:present?) if fields
          @multi_searchable
        end
      end
    end
  end
end
