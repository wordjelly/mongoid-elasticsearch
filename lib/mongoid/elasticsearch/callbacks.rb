module Mongoid
  module Elasticsearch
    module Callbacks
      extend ActiveSupport::Concern

      included do
        after_save :update_es_index
        after_destroy :update_es_index
        
        ## THIS FUNCTION HAS BEEN UPDATED TO DO THE UPDATE ONLY IF THE OP_SUCCESS IS TRUE OR NIL, IN CASE THE RECORD RESPONDS TO OP_SUCCESS.
        def update_es_index
          if self.respond_to? :op_success
            if self.op_success.nil?
              es_update
            else
              es_update if self.op_success == true
            end
          else
            es_update
          end
        end
      end

      module ClassMethods
        def without_es_update!( &block )
          skip_callback( :save, :after, :update_es_index )
          skip_callback( :destroy, :after, :update_es_index )
          
          result = yield

          set_callback( :save, :after, :update_es_index )
          set_callback( :destroy, :after, :update_es_index )
          
          result
        end
      end
    end
  end
end

