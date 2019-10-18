# partially based on https://github.com/karmi/retire/blob/master/lib/tire/results/collection.rb

require 'mongoid/elasticsearch/pagination'

module Mongoid
  module Elasticsearch
    class Response
      include Enumerable
      include Pagination

      attr_reader :time, :total, :options, :facets, :max
      attr_reader :response

      def initialize(client, query, multi, model, options)
        @client  = client
        @query   = query
        @multi   = multi
        @model   = model
        @wrapper = options[:wrapper]
        @options = options
      end

      def perform!
        response = @client.search(@query)
        @options = options
        @time = response['took'].to_i
        @total = response['hits']['total'].to_i rescue nil
        @facets = response['facets']
        @max_score = response['hits']['max_score'].to_f rescue nil
        response
      end

      def total
        if @total.nil?
          perform!
          @total
        else
          @total
        end
      end

      def raw_response
        @raw_response ||= perform!
      end

      def hits
        @hits ||= raw_response['hits']['hits']
      end

      def results
        return [] if failure?
        @results ||= begin
          #puts "here are the hits."
          #puts JSON.pretty_generate(hits)
          case @wrapper
          when :load
            if @multi
              multi_with_load
            else
              records = @model.find(hits.map { |h| h['_id'] })
              hits.map do |item|
                records.detect do |record|
                  record.id.to_s == item['_id'].to_s
                end
              end
            end
          when :mash
          
            hits.map do |h|
              s = h.delete('_source')
              m = Hashie::Mash.new(h.merge(s))
              if defined?(Moped::BSON)
                m.id = Moped::BSON::ObjectId.from_string(h['_id'])
              else
          
                m.id = BSON::ObjectId.from_string(h['_id'])
              end
              m._id = m.id
              m
            end
          when :model
          
            multi_without_load
          else
            hits
          end

        end



      

      end

      def error
        raw_response['error']
      end

      def success?
        error.to_s.empty?
      end

      def failure?
        !success?
      end

      def each(&block)
        results.each(&block)
      end

      def to_ary
        results
      end

      def inspect
        "#<Mongoid::Elasticsearch::Response @size:#{@results.nil? ? 'not run yet' : size} @results:#{@results.inspect} @raw_response=#{@raw_response}>"
      end

      def count
        # returns approximate counts, for now just using search_type: 'count',
        # which is exact
        # @total ||= @client.count(@query)['count']

        @total ||= @client.search(@query.merge(search_type: 'count'))['hits']['total']
      end

      def size
        results.size
      end
      alias_method :length, :size

      private

      def find_klass(type)
        raise NoMethodError, "You have tried to eager load the model instances, " +
                             "but Mongoid::Elasticsearch cannot find the model class because " +
                             "document has no _type property." unless type

        begin
          klass = type.camelize.singularize.constantize
        rescue NameError => e
          raise NameError, "You have tried to eager load the model instances, but " +
                           "Mongoid::Elasticsearch cannot find the model class '#{type.camelize}' " +
                           "based on _type '#{type}'.", e.backtrace
        end
      end

      def multi_with_load
        #puts "--------------- Inside multi with load -------------"
        #puts "returned since hits were empty."
        return [] if hits.empty?
        #puts "hits not empty."
        #type has been shorted out to be document_type
        #type for all documents is the same and it is called 'document'
        #so now the document_type is the actual class of the model.
        records = {}
        hits.group_by { |item| item['_source']['document_type'] }.each do |type, items|
          klass = find_klass(type)
          ####################################################
          ##
          ##
          ## THIS LINE REMOVED AND SUBSEQUENT BLOCK ADDED.
          ##
          ##
          ####################################################
          #records[type] = klass.find(items.map { |h| h['_id'] })

          ####################################################
          ##
          ##
          ##
          ## WHOLE SUBSEQUENT BLOCK IS ADDED.
          ##
          ##
          ####################################################
          items.each do |h|
            begin
              records[type]||= []
              records[type] << klass.find(h['_id'])
            rescue => e
              puts e.to_s
            end
          end

        end

        # Reorder records to preserve the order from search results
        hits.map do |item|
          ### THIS LINE WAS ADDED TO CHECK IF THE TYPE EXISTS.
          if records[item['_source']['document_type']]
            records[item['_source']['document_type']].detect do |record|
              record.id.to_s == item['_id'].to_s
            end
          end
        end
      end

      def multi_without_load
        hits.map do |h|
          klass = find_klass(h['_source']['document_type'])
          h[:_highlight] = h.delete('highlight') if h.key?('highlight')
          source = h.delete('_source')
          if defined?(Moped::BSON)
            source.each do |k,v|
              if v.is_a?(Hash) && v.has_key?("$oid")
                source[k] = Moped::BSON::ObjectId.from_string(v["$oid"])
              end
            end
          else
            source.each do |k,v|
              if v.is_a?(Hash) && v.has_key?("$oid")
                source[k] = BSON::ObjectId.from_string(v["$oid"])
              end
            end
          end
          begin
            m = klass.new(h.merge(source))
            if defined?(Moped::BSON)
              m.id = Moped::BSON::ObjectId.from_string(h['_id'])
            else
              m.id = BSON::ObjectId.from_string(h['_id'])
            end
          rescue Mongoid::Errors::UnknownAttribute
            klass.class_eval <<-RUBY, __FILE__, __LINE__+1
              attr_accessor :_type, :_score, :_source, :_highlight
            RUBY
            m = klass.new(h.merge(source))
          end
          m.new_record = false
          m
        end
      end
    end
  end
end
