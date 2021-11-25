# typed: strict
# frozen_string_literal: true

require "parser/current"

# opt-in to most recent AST format
::Parser::Builders::Default.emit_lambda               = true
::Parser::Builders::Default.emit_procarg0             = true
::Parser::Builders::Default.emit_encoding             = true
::Parser::Builders::Default.emit_index                = true
::Parser::Builders::Default.emit_arg_inside_procarg0  = true