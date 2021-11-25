# typed: strict
# frozen_string_literal: true

module Spoom
  module Code
    class Send
      extend T::Sig

      sig { returns(String) }
      attr_reader :method_name

      sig { returns(::AST::Node) }
      attr_reader :node

      sig { returns(T.nilable(::AST::Node)) }
      attr_reader :recv_node

      sig { returns(Loc) }
      attr_reader :loc, :selector_loc

      sig { returns(T.nilable(Loc)) }
      attr_reader :recv_loc

      # TODO: save recv string

      sig do
        params(
          method_name: String,
          node: ::AST::Node,
          recv_node: T.nilable(::AST::Node),
          loc: Loc,
          recv_loc: T.nilable(Loc),
          selector_loc: Loc
        ).void
      end
      def initialize(method_name, node:, recv_node:, loc:, recv_loc:, selector_loc:)
        @method_name = method_name
        @node = node
        @recv_node = recv_node
        @loc = loc
        @recv_loc = recv_loc
        @selector_loc = selector_loc
      end

      sig { returns(String) }
      def to_s
        "#{method_name} (#{loc})"
      end
    end

    class CollectSends
      extend T::Sig

      EXCLUDED_SENDS = T.let([
        "include", "extend", "require", "require_relative", "private", "protected", "super",
        "sig", "params", "returns", "void", "nilable", "unsafe", "let", "const", "prop", "override"
      ], T::Array[String])

      sig { returns(T::Array[Send]) }
      attr_reader :sends

      sig { void }
      def initialize
        @sends = T.let([], T::Array[Send])
      end

      sig { params(file: String).void }
      def analyze_file(file)
        FileVisitor.new(self, file).enter_file
      end

      sig { params(file: String, node: ::AST::Node).void }
      def record_send(file, node)
        name = node.children[1].to_s

        return unless accept_send?(name)

        recv_node = node.children.first
        recv_loc = if recv_node
          Loc.from_ast_loc(file, recv_node.location.expression)
        end

        @sends << Send.new(
          name,
          node: node,
          recv_node: recv_node,
          loc: Loc.from_ast_loc(file, node.location),
          recv_loc: recv_loc,
          selector_loc: Loc.from_ast_loc(file, node.location.selector)
        )
      end

      private

      sig { params(name: String).returns(T::Boolean) }
      def accept_send?(name)
        !EXCLUDED_SENDS.include?(name)
      end

      class FileVisitor
        extend T::Sig

        sig { params(collector: CollectSends, file: String).void }
        def initialize(collector, file)
          @collector = collector
          @file = file
        end

        sig { void }
        def enter_file
          contents = File.read(@file)
          node = ::Parser::CurrentRuby.parse(contents)
          visit(node)
        rescue ::Parser::SyntaxError => e
          raise "ParseError (#{e})"
          # raise ParseError.new(e.message, Loc.from_ast_loc(file, e.diagnostic.location))
        end

        private

        sig { params(node: T.nilable(Object)).void }
        def visit(node)
          return unless node.is_a?(AST::Node)

          @collector.record_send(@file, node) if node.type == :send

          node.children.each { |child| visit(child) }
        end
      end
    end
  end
end
