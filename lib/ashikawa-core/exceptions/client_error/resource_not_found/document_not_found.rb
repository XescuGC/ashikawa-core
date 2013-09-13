# -*- encoding : utf-8 -*-
require "ashikawa-core/exceptions/client_error/resource_not_found"

module Ashikawa
  module Core
    # This Exception is thrown when a document was requested from
    # the server that does not exist.
    class DocumentNotFoundException < ResourceNotFound
      # String representation of the exception
      #
      # @return String
      # @api private
      def to_s
        "You requested a document from the server that does not exist"
      end
    end
  end
end
