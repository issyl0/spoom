# typed: false

require "spoom"
require "sorbet-runtime"

module Spoom
  module Sorbet
    class Node; end

    class ClassDef
    end

    class ModuleDef
    end

    class MethodDef
    end

    class AttrDef
    end

    class ConstDef
    end

    class TreeVisitor
      def initialize
        @indent = 0
      end

      def visit(symbol)
        if symbol.is_a? Symbol
          visit_symbol(symbol)
        elsif symbol.is_a? Array
          visit_symbols(symbol)
        end
      end

      def visit_symbol(symbol)
        puts "#{" " * @indent}#{symbol.qname}"
        @indent += 2
        visit_symbols(symbol.children)
        @indent -= 2
      end

      def visit_symbols(symbols)
        symbols.each { |symbol| visit_symbol(symbol) }
      end
    end

    class TreeParser
      extend T::Sig

      # sig { params(object: T.nilable(T::Hash[String, T.untyped]), parent: T.nilable(Symbol)).returns(T.nilable(Symbol)) }
      def parse_node(object, parent = nil)
        if object.is_a? Array
          parse_nodes(object)
          return nil
        end

        return nil unless object.is_a? Hash
        puts object

        type = object.fetch("type")
        case type
        when "Begin"
          parse_begin(object)
        when "Module"
          parse_module(object)
        when "Class"
          parse_class(object)
        # TODO
        #const
        #sends (sig, incluide, extend, prepend, attr)
        #super class
        # names
          # parent
          # children
          # def methgod
          # self metghods
        end
        # name = object.fetch("name")
        # name = name.fetch("name") if name.is_a?(Hash)
        # return nil if name != "<root>" and name =~ /[<>()$]/
#
        # symbol = Symbol.new(parent: parent, kind: kind, name: name)
        # symbol.children.concat parse_symbols(object["children"], symbol)
        # symbol
        nil
      end

      # sig { params(objects: T.nilable(T::Array[T.untyped]), parent: T.nilable(Symbol)).returns(T::Array[Symbol]) }
      def parse_nodes(objects, parent = nil)
        nodes = []
        return nodes unless objects

        objects.each do |object|
          node = parse_node(object, parent)
          nodes << node if node
        end
        nodes
      end

      def parse_begin(object)
        parse_nodes(object["stmts"])
      end

      def parse_module(object)
        parse_nodes(object["body"])
      end

      def parse_class(object)
        parse_nodes(object["body"])
      end
    end
  end
end

out, status = Spoom::Sorbet.srb_tc("--stop-after parser", "--print", "parse-tree-json", "--no-config", "test_small.rb", "test_small2.rb", capture_err: false)
return unless status

out.gsub!(/}\n{/, "},\n{")
out = "[#{out}]"

json = JSON.parse(out)
tree = Spoom::Sorbet::TreeParser.new.parse_nodes(json)
Spoom::Sorbet::TreeVisitor.new.visit(tree)
