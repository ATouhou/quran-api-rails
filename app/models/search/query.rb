module Search
  module Query
    class Client
      TYPE_HITS = :hits
      TYPE_AGGREGATIONS = :aggregations

      include Search::Query::Aggregations
      include Search::Query::Highlight
      include Search::Query::Fields
      include Search::Query::Indices

      include Virtus.model

      attribute :page, Integer, default: 1
      attribute :size, Integer, default: 20
      attribute :start_time, Time
      attribute :end_time, Time
      attribute :delta_time, Float
      attribute :indices_boost, Hash
      attribute :query, Search::Query::Query

      # Computed
      attribute :total, Integer
      attribute :response, Search::Results
      attribute :ayah_keys, Array
      attribute :type, Symbol, default: TYPE_AGGREGATIONS

      # Options
      # attribute :highlight, Boolean, default: true
      attribute :prefix_length, Integer, default: 1
      attribute :fuzziness, Integer, default: 1


      def initialize(query, options = {})
        @page = options[:page].to_i
        @size = options[:size].to_i
        @type = options[:type]

        @indices_boost = options[:indices_boost]
        @query = Search::Query::Query.new(query)

        @prefix_length = options[:prefix_length]
        # Fuzziness describes the distance from the actual word
        # see: https://www.elastic.co/blog/found-fuzzy-search
        @fuzziness = options[:fuzziness]

        @content = options[:content]
        @audio = options[:audio]
      end

      def search_params
        {
          index: indices,
          type: :data,
          explain: explain,
          body: {
            indices_boost: index_boost,
            highlight: highlight,
            aggregations: aggregations,
            from: from,
            size: size_query,
            # May not need this after all.
            # fields: fields,
            _source: source,
            query: query_object
          }
        }
      end

      def request
        @start_time = Time.now
        @ayah_keys = Search::Request.new(search_params, @type).search.keys
        @total = @ayah_keys.length
        @type = :hits
        @response = Search::Request.new(search_params, @type).search
        @end_time = Time.now
        @delta_time = @end_time - @start_time

        self

      rescue

        handle_error
        self
      end

      def handle_error
        @errored = true
      end

      def errored?
        @errored
      end

      def explain
        # debugging... on or off?
        false
      end

      def hits_query?
        # Could be :raw or :aggregation
        @type == :hits
      end

      def aggregations_query?
        @type == :aggregations
      end

      def size_query
        if self.hits_query?
          @size
        else
          0
        end
      end

      def from
        (@page - 1) * @size
      end

      def source
        if self.hits_query?
          ['text', 'resource.*', 'language.*']
        else
          []
        end
      end

      def terms
        {
          terms: {
            # Ayah keys go here, make sure they are underscored like 1_2
            'ayah.ayah_key' => Kaminari.paginate_array(@ayah_keys).page(@page).per(@size)
          }
        }
      end

      def simple_query_string
        {
          simple_query_string: {
            query: @query.query,
            # default_field: "_all",
            # lenient: true,
            fields: fields_val,
            minimum_should_match: '85%'
          }
        }
      end

      def query_string
        {
          query_string: {
            query: @query.query,
            #  We could use this for later but it adds unneeded time.
            # default_field: "_all",
            auto_generate_phrase_queries: true,
            lenient: true,
            fields: fields_val,
            minimum_should_match: '95%'
          }
        }
      end

      def query_object
        query = {
          bool: {
            must: [
              query_string
            ]
          }
        }

        query[:bool][:must].unshift(terms) if hits_query?

        query
      end
    end
  end
end
