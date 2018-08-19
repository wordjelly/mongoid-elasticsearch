module Mongoid
  module Elasticsearch
    class Index
      def initialize(es)
        @es = es
      end

      def klass
        @es.klass
      end

      def name
        klass.es_index_name
      end

      ## mapping names should not be specified, it will direclty use the type from here, which will default to document.
      ## if specified, mapping name should be document.
      ## this was modified to set the type of all documents as "document", because in newer versions elasticsearch supports only one mapping/type per index.
      def type
        "document"
        #klass.model_name.collection.singularize
      end

      def options
        klass.es_index_options
      end

      def indices
        @es.client.indices
      end

      def exists?
        indices.exists index: name
      end

      def create
        unless options == {} || exists?
          force_create
        end
      end

      def force_create
        indices.create index: name, body: options
      end

      def delete
        if exists?
          force_delete
        end
      end

      def force_delete
        indices.delete index: name
      end

      def refresh
        indices.refresh index: name
      end

      def reset
        delete
        create
      end
    end
  end
end
