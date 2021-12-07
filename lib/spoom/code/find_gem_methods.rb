# typed: strict
# frozen_string_literal: true

module Spoom
  module Code
    class FindGemMethods < RBI::Visitor
      extend T::Sig

      sig { void }
      def initialize
        @names_to_methods = T.let({}, T::Hash[String, T::Array[RBI::Method]])
      end

      sig { override.params(node: T.nilable(RBI::Node)).void }
      def visit(node)
        return unless node

        case node
        when RBI::Tree
          visit_all(node.nodes)
        when RBI::Method
          (@names_to_methods[node.name] ||= []) << node
        end
      end

      sig { params(name: String).returns(T::Array[RBI::Method]) }
      def name_to_methods(name)
        @names_to_methods[name] || []
      end
    end
  end
end
