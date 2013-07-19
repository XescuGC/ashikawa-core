require "ashikawa-core/exceptions/client_error/resource_not_found/collection_not_found"
require "ashikawa-core/collection"
require "ashikawa-core/connection"
require "ashikawa-core/cursor"
require "ashikawa-core/configuration"
require "forwardable"

module Ashikawa
  module Core
    # An ArangoDB database
    class Database
      COLLECTION_TYPES = {
        :document => 2,
        :edge => 3
      }

      extend Forwardable

      # Delegate sending requests to the connection
      def_delegator :@connection, :send_request
      def_delegator :@connection, :host
      def_delegator :@connection, :port
      def_delegator :@connection, :scheme
      def_delegator :@connection, :authenticate_with

      # Initializes the connection to the database
      #
      # @api public
      # @example Access a Database by providing the URL
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = "http://localhost:8529"
      #   end
      # @example Access a Database by providing a Connection
      #   connection = Connection.new("http://localhost:8529")
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.connection = connection
      #   end
      # @example Access a Database with a logger and custom HTTP adapter
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = "http://localhost:8529"
      #     config.adapter = my_adapter
      #     config.logger = my_logger
      #   end
      def initialize
        configuration = Ashikawa::Core::Configuration.new
        yield(configuration)
        @connection = configuration.connection || setup_new_connection(configuration.url, configuration.logger, configuration.adapter)
      end

      # Returns a list of all collections defined in the database
      #
      # @return [Array<Collection>]
      # @api public
      # @example Get an Array containing the Collections in the database
      #   database = Ashikawa::Core::Database.new("http://localhost:8529")
      #   database["a"]
      #   database["b"]
      #   database.collections # => [ #<Collection name="a">, #<Collection name="b">]
      def collections(system = false)
        raw_collections = send_request("collection")["collections"]
        raw_collections.delete_if { |collection| collection["name"].start_with?("_") } unless system
        parse_raw_collections(raw_collections)
      end

      # Create a Collection based on name
      #
      # @param [String] collection_identifier The desired name of the collection
      # @option opts [Boolean] :is_volatile Should the collection be volatile? Default is false
      # @option opts [Boolean] :content_type What kind of content should the collection have? Default is :document
      # @return [Collection]
      # @api public
      # @example Create a new, volatile collection
      #   database = Ashikawa::Core::Database.new("http://localhost:8529")
      #   database.create_collection("a", :isVolatile => true) # => #<Collection name="a">
      def create_collection(collection_identifier, opts = {})
        response = send_request("collection", :post => translate_params(collection_identifier, opts))
        Ashikawa::Core::Collection.new(self, response)
      end

      # Get or create a Collection based on name or ID
      #
      # @param [String, Fixnum] collection_identifier The name or ID of the collection
      # @return [Collection]
      # @api public
      # @example Get a Collection from the database by name
      #   database = Ashikawa::Core::Database.new("http://localhost:8529")
      #   database["a"] # => #<Collection name="a">
      # @example Get a Collection from the database by ID
      #   database = Ashikawa::Core::Database.new("http://localhost:8529")
      #   database["7254820"] # => #<Collection id=7254820>
      def collection(collection_identifier)
        begin
          response = send_request("collection/#{collection_identifier}")
        rescue CollectionNotFoundException
          response = send_request("collection", :post => { :name => collection_identifier })
        end

        Ashikawa::Core::Collection.new(self, response)
      end

      alias :[] :collection

      # Return a Query initialized with this database
      #
      # @return [Query]
      # @api public
      # @example Send an AQL query to the database
      #   database = Ashikawa::Core::Database.new("http://localhost:8529")
      #   database.query.execute "FOR u IN users LIMIT 2" # => #<Cursor id=33>
      def query
        Query.new(self)
      end

      private

      # Setup the connection object
      #
      # @param [String] url
      # @param [Logger] logger
      # @param [Adapter] adapter
      # @return [Connection]
      # @api private
      def setup_new_connection(url, logger, adapter)
        raise(ArgumentError, "Please provide either an url or a connection to setup the database") if url.nil?
        Ashikawa::Core::Connection.new(url, {
          :logger => logger,
          :adapter => adapter
        })
      end

      # Parse a raw collection
      #
      # @param [Array] raw_collections
      # @return [Array]
      # @api private
      def parse_raw_collections(raw_collections)
        raw_collections.map { |collection|
          Ashikawa::Core::Collection.new(self, collection)
        }
      end

      # Translate the key options into the required format
      #
      # @param [Hash] key_options
      # @return [Hash]
      # @api private
      def translate_key_options(key_options)
        {
          :type => key_options[:type].to_s,
          :offset => key_options[:offset],
          :increment => key_options[:increment],
          :allowUserKeys => key_options[:allow_user_keys]
        }
      end

      # Translate the params into the required format
      #
      # @param [String] collection_identifier
      # @param [Hash] opts
      # @return [Hash]
      # @api private
      def translate_params(collection_identifier, opts)
        params = { :name => collection_identifier }
        params[:isVolatile] = true if opts[:is_volatile] == true
        params[:type] = COLLECTION_TYPES[opts[:content_type]] if opts.has_key?(:content_type)
        params[:keyOptions] = translate_key_options(opts[:key_options]) if opts.has_key?(:key_options)
        params
      end
    end
  end
end
