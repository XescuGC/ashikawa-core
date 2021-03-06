# -*- encoding : utf-8 -*-
require 'ashikawa-core/exceptions/client_error/resource_not_found/collection_not_found'
require 'ashikawa-core/exceptions/client_error/resource_not_found/graph_not_found'
require 'ashikawa-core/collection'
require 'ashikawa-core/graph'
require 'ashikawa-core/connection'
require 'ashikawa-core/cursor'
require 'ashikawa-core/configuration'
require 'ashikawa-core/transaction'
require 'forwardable'
require 'equalizer'

module Ashikawa
  module Core
    # An ArangoDB database
    class Database
      # ArangoDB defines two different kinds of collections: Document and Edge Collections
      COLLECTION_TYPES = {
        document: 2,
        edge: 3
      }

      extend Forwardable

      include Equalizer.new(:host, :port, :scheme)

      # Delegate sending requests to the connection
      def_delegator :@connection, :send_request
      def_delegator :@connection, :host
      def_delegator :@connection, :port
      def_delegator :@connection, :scheme

      # Initializes the connection to the database
      #
      # @api public
      # @example Access a Database by providing the URL
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #   end
      # @example Access a Database by providing a Connection and authentication
      #   connection = Connection.new('http://localhost:8529', '_system')
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.connection = connection
      #     config.username = 'lebowski'
      #     config.password = 'i<3bowling'
      #   end
      # @example Access a certain database from ArangoDB
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #     config.connection = connection
      #     config.database_name = 'my_db'
      #   end
      # @example Access a Database with a logger and custom HTTP adapter
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #     config.adapter = my_adapter
      #     config.logger = my_logger
      #   end
      def initialize
        configuration = Configuration.new
        yield(configuration)
        @connection = configuration.connection
      end

      # Create the database
      #
      # @example Create a new database with the name 'ashikawa'
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #     config.database_name = 'ashikawa'
      #   end
      #   database.create
      def create
        @connection.send_request_without_database_suffix('database', post: { name: @connection.database_name })
      end

      # Drop the database
      #
      # @example Drop a new database with the name 'ashikawa'
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #     config.database_name = 'ashikawa'
      #   end
      #   database.drop
      def drop
        @connection.send_request_without_database_suffix("database/#{name}", delete: {})
      end

      # Truncate all collections of the database
      #
      # @example Truncate all collections of the database
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #   end
      #   database.truncate
      def truncate
        collections.each { |collection| collection.truncate }
      end

      # The name of the database
      #
      # @return [String]
      # @api public
      # @example Get the name of the databasse
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #     config.database_name = 'ashikawa'
      #   end
      #   database.name # => 'ashikawa'
      def name
        @connection.database_name
      end

      # Get a list of all databases
      #
      # @api public
      # @example Get a list of all databases
      #   database = Ashikawa::Core::Database.new do |config|
      #     config.url = 'http://localhost:8529'
      #   end
      #   database.all_databases # => ['_system']
      def all_databases
        send_request('database')['result']
      end

      # Returns a list of all non-system collections defined in the database
      #
      # @return [Array<Collection>]
      # @api public
      # @example Get an Array containing the Collections in the database
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database['a']
      #   database['b']
      #   database.collections # => [ #<Collection name='a'>, #<Collection name="b">]
      def collections
        all_collections_where { |collection| !collection['name'].start_with?('_') }
      end

      # Returns a list of all system collections defined in the database
      #
      # @return [Array<Collection>]
      # @api public
      # @example Get an Array containing the Collections in the database
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database.system_collections # => [ #<Collection name='_a'>, #<Collection name="_b">]
      def system_collections
        all_collections_where { |collection| collection['name'].start_with?('_') }
      end

      # Create a Collection based on name
      #
      # @param [String] collection_identifier The desired name of the collection
      # @option options [Boolean] :is_volatile Should the collection be volatile? Default is false
      # @option options [Boolean] :content_type What kind of content should the collection have? Default is :document
      # @return [Collection]
      # @api public
      # @example Create a new, volatile collection
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database.create_collection('a', :isVolatile => true) # => #<Collection name="a">
      def create_collection(collection_identifier, options = {})
        response = send_request('collection', post: translate_params(collection_identifier, options))
        Collection.new(self, response)
      end

      # Get or create a Collection based on name or ID
      #
      # @param [String, Fixnum] collection_identifier The name or ID of the collection
      # @return [Collection]
      # @api public
      # @example Get a Collection from the database by name
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database['a'] # => #<Collection name="a">
      # @example Get a Collection from the database by ID
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database['7254820'] # => #<Collection id=7254820>
      def collection(collection_identifier)
        response = send_request("collection/#{collection_identifier}")
        Collection.new(self, response)
      rescue CollectionNotFoundException
        create_collection(collection_identifier)
      end

      alias_method :[], :collection

      # Return a Query initialized with this database
      #
      # @return [Query]
      # @api public
      # @example Send an AQL query to the database
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database.query.execute 'FOR u IN users LIMIT 2' # => #<Cursor id=33>
      def query
        Query.new(self)
      end

      # Create a new Transaction for this database
      #
      # @param [String] action The JS action you want to execute
      # @option collections [Array<String>] :read The collections you want to read from
      # @option collections [Array<String>] :write The collections you want to write to
      # @return [Object] The result of the transaction
      # @api public
      # @example Create a new Transaction
      #   transaction = database.create_transaction('function () { return 5; }", :read => ["collection_1'])
      #   transaction.execute #=> 5
      def create_transaction(action, collections)
        Transaction.new(self, action, collections)
      end

      # Fetch a single graph from this database or creates it if does not exist yet.
      #
      # @param [String] graph_name The name of the Graph
      # @return [Graph] The requested graph
      # @api public
      def graph(graph_name)
        response = send_request("gharial/#{graph_name}")
        Graph.new(self, response['graph'])
      rescue Ashikawa::Core::GraphNotFoundException
        return create_graph(graph_name)
      end

      # Create a new Graph for this database.
      #
      # @param [String] graph_name The name of the Graph
      # @option options [Array<Hash>] :edge_definitions A list of edge definitions
      # @option options [Array<String>] :orphan_collections A list of orphan collections
      # @return [Graph] The graph that was created
      # @api public
      # @example Create a graph without additional options
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database.create_graph('a') # => #<Graph name="a">
      # @example Create a graph with edge definitions and orphan collections
      #   database = Ashikawa::Core::Database.new('http://localhost:8529')
      #   database.create_graph('g', {
      #       edge_definitions: [{ collection: 'c', from: 'a', to: 'b'}],
      #       orphan_collections: ['d']
      #     })
      def create_graph(graph_name, options = {})
        response = send_request('gharial', post: translate_params(graph_name, options))
        Graph.new(self, response['graph'])
      end

      # Fetch all graphs for this database
      def graphs
        response = send_request('gharial')
        response['graphs'].map { |raw_graph| Graph.new(self, raw_graph) }
      end

      private

      # Parse a raw collection
      #
      # @param [Array] raw_collections
      # @return [Array]
      # @api private
      def parse_raw_collections(raw_collections)
        raw_collections.map { |collection| Collection.new(self, collection) }
      end

      # Translate the key options into the required format
      #
      # @param [Hash] key_options
      # @return [Hash]
      # @api private
      def translate_key_options(key_options)
        {
          type: key_options[:type].to_s,
          offset: key_options[:offset],
          increment: key_options[:increment],
          allowUserKeys: key_options[:allow_user_keys]
        }
      end

      # Translate the params into the required format
      #
      # @param [String] identifier
      # @param [Hash] opts
      # @return [Hash]
      # @api private
      def translate_params(identifier, opts)
        params = { name: identifier }
        params[:edgeDefinitions] = opts[:edge_definitions] if opts.key?(:edge_definitions)
        params[:orphanCollections] = opts[:orphan_collections] if opts.key?(:orphan_collections)
        params[:isVolatile] = true if opts[:is_volatile]
        params[:type] = COLLECTION_TYPES[opts[:content_type]] if opts.key?(:content_type)
        params[:keyOptions] = translate_key_options(opts[:key_options]) if opts.key?(:key_options)
        params
      end

      # Get all collections that fulfill a certain criteria
      #
      # @yield [raw_collection] Yields the raw collections so you can decide which to keep
      # @yieldparam [raw_collection] A raw collection
      # @yieldreturn [Boolean] Should the collection be kept
      # @return [Array<Collection>]
      # @api private
      def all_collections_where(&block)
        raw_collections = send_request('collection')['collections']
        raw_collections.keep_if(&block)
        parse_raw_collections(raw_collections)
      end
    end
  end
end
