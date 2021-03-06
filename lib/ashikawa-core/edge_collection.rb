# -*- encoding : utf-8 -*-
require 'ashikawa-core/collection'
require 'ashikawa-core/edge'

module Ashikawa
  module Core
    # An edge collection as it is returned from a graph
    #
    # @note This is basically just a regular collection with some additional attributes and methods to ease
    #       working with collections in the graph module.
    class EdgeCollection < Collection
      # The prepared AQL statement to remove edges
      REMOVE_EDGES_AQL_STATEMENT = <<-AQL.gsub(/^[ \t]*/, '')
      FOR e IN @@edge_collection
        FILTER e._from == @from && e._to == @to
        REMOVE e._key IN @@edge_collection
      AQL

      # The Graph instance this EdgeCollection was originally fetched from
      #
      # @return [Graph] The Graph instance the collection was fetched from
      # @api public
      attr_reader :graph

      # Create a new EdgeCollection object
      #
      # @param [Database] database The database the connection belongs to
      # @param [Hash] raw_collection The raw collection returned from the server
      # @param [Graph] graph The graph from which this collection was fetched
      # @note You should not create instance manually but rather use Graph#add_edge_definition
      # @api public
      def initialize(database, raw_collection, graph)
        super(database, raw_collection)
        @graph = graph
      end

      # Create one or more edges between documents with certain attributes
      #
      # @param [Document] from The outbound vertex
      # @param [Document] to The inbound vertex
      # @param [Hash] attributes Additional attributes to add to all created edges
      # @return [Edge] The created Edge
      # @api public
      # @example Create an edge between two vertices
      #   edges = edge_collection.add(from: vertex_a, to: vertex_b)
      def add(directions)
        from_vertex, to_vertex = directions.values_at(:from, :to)
        response = send_request_for_this_collection('', post: { _from: from_vertex.id, _to: to_vertex.id })
        fetch(response['edge']['_key'])
      end

      # Remove edges by example
      #
      # @note This will remove ALL edges between the given vertices. For more fine grained control delete
      #       the desired edges through Edge#remove.
      # @param [Hash] from_to Specifies the edge by its vertices to be removed
      # @option from_to [Document] from The from part of the edge
      # @option from_to [Document] to The to part of the edge
      # @api public
      def remove(from_to)
        bind_vars = {
          :@edge_collection => name,
          :from             => from_to[:from].id,
          :to               => from_to[:to].id
        }

        database.query.execute(REMOVE_EDGES_AQL_STATEMENT, bind_vars: bind_vars)
      end

      # Builds a new edge object and passes the current graph to it
      #
      # @param [Hash] data The raw data to be used to instatiate the class
      # @param [Hash] additional_atttributes Initial attributes to be passed to the Edge
      # @return [Edge] The instatiated edge
      # @api private
      def build_content_class(data, additional_atttributes = {})
        Edge.new(@database, data, additional_atttributes.merge(graph: graph))
      end

      private

      # Send a request to the server through the Graph module
      #
      # @param [String] path The requested path
      # @param [Hash] method The desired HTTP Verb (defaults to GET) and its parameters
      # @return [Hash] Response from the server
      # @api private
      def send_request_for_this_collection(path, method = {})
        send_request("gharial/#{graph.name}/edge/#@name/#{path}", method)
      end
    end
  end
end
