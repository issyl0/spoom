# typed: ignore

require "spoom"
require "sorbet-runtime"

module Spoom
  module Sorbet
    class Symbol < T::Struct
      extend T::Sig

      const :kind, String
      const :parent, T.nilable(Symbol), default: nil
      const :name, String
      const :children, T::Array[Symbol], default: []

      sig { returns(String) }
      def qname
        name = case kind
        when "CLASS_OR_MODULE", "STATIC_FIELD"
          "::"
        when "METHOD"
          "#"
        else
          "?"
        end
        name += self.name
        return name unless parent && !parent.is_root
        "#{parent.qname}#{name}"
      end

      sig { returns(T::Boolean) }
      def is_root
        name == "<root>"
      end

      sig { returns(String) }
      def to_s
        "#{kind}:#{name}"
      end
    end

    class SymbolVisitor
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

    class SymbolTableParser
      extend T::Sig

      sig { params(object: T.nilable(T::Hash[String, T.untyped]), parent: T.nilable(Symbol)).returns(T.nilable(Symbol)) }
      def parse_symbol(object, parent = nil)
        return nil unless object

        kind = object.fetch("kind")
        name = object.fetch("name")
        name = name.fetch("name") if name.is_a?(Hash)
        return nil if name != "<root>" and name =~ /[<>()$]/

        symbol = Symbol.new(parent: parent, kind: kind, name: name)
        symbol.children.concat parse_symbols(object["children"], symbol)
        symbol
      end

      sig { params(objects: T.nilable(T::Array[T.untyped]), parent: T.nilable(Symbol)).returns(T::Array[Symbol]) }
      def parse_symbols(objects, parent = nil)
        symbols = []
        return symbols unless objects

        objects.each do |object|
          symbol = parse_symbol(object, parent)
          symbols << symbol if symbol
        end
        symbols
      end
    end

    class Model
      attr_reader :symbols

      def initialize
        @symbols = {}
      end

      def add_symbol(symbol)
        @symbols[symbol.qname] = symbol
      end
    end
  end
end

out, status = Spoom::Sorbet.srb_tc("--print symbol-table-json", capture_err: false)
return unless status

json = JSON.parse(out)
symbols = Spoom::Sorbet::SymbolTableParser.new.parse_symbol(json)
Spoom::Sorbet::SymbolVisitor.new.visit(symbols)
