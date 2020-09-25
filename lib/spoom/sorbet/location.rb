# typed: strict
# frozen_string_literal: true

# TODO reuse in error parser
# TODO reuse in LSP?

module Spoom
  module Sorbet
    class Location
      extend T::Sig

      sig { returns(T.nilable(String)) }
      attr_reader :file

      sig { returns(T.nilable(T.any(Range, Position))) }
      attr_reader :position

      sig { params(file: T.nilable(String), position: T.nilable(T.any(Range, Position))).void }
      def initialize(file = nil, position = nil)
        @file = file
        @position = position
      end

      sig { returns(String) }
      def to_s
        "#{file}:#{position}"
      end
    end

    class Range
      extend T::Sig

      sig { returns(Position) }
      attr_reader :from, :to

      sig { params(from: Position, to: Position).void }
      def initialize(from, to)
        @from = from
        @to = to
      end

      sig { returns(String) }
      def to_s
        "#{from}-#{to}"
      end
    end

    class Position
      extend T::Sig

      sig { returns(Integer) }
      attr_reader :line, :column

      sig { params(line: Integer, column: Integer).void }
      def initialize(line, column)
        @line = line
        @column = column
      end

      sig { returns(String) }
      def to_s
        "#{line}:#{column}"
      end
    end
  end
end
