# typed: strict
# frozen_string_literal: true

module Spoom
  module Code
    class Loc
      extend T::Sig

      sig { returns(String) }
      attr_reader :file

      sig { returns(Integer) }
      attr_reader :begin_line, :end_line, :begin_column, :end_column

      sig { params(file: String, ast_loc: T.any(::Parser::Source::Map, ::Parser::Source::Range)).returns(Loc) }
      def self.from_ast_loc(file, ast_loc)
        Loc.new(
          file: file,
          begin_line: ast_loc.line,
          begin_column: ast_loc.column,
          end_line: ast_loc.last_line,
          end_column: ast_loc.last_column
        )
      end

      sig do
        params(
          file: String,
          begin_line: Integer,
          end_line: Integer,
          begin_column: Integer,
          end_column: Integer
        ).void
      end
      def initialize(file:, begin_line:, end_line:, begin_column:, end_column:)
        @file = file
        @begin_line = begin_line
        @end_line = end_line
        @begin_column = begin_column
        @end_column = end_column
      end

      sig { returns(String) }
      def to_s
        "#{file}:#{begin_line}:#{begin_column}-#{end_line}:#{end_column}"
      end
    end
  end
end
