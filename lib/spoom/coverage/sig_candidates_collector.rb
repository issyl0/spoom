# typed: strict
# frozen_string_literal: true

require "parser/current"

module Spoom
  module SigCandidates
    class Method
      extend T::Sig
      include Comparable

      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[AST::Node]) }
      attr_reader :sig_nodes

      sig { returns(T::Boolean) }
      attr_reader :singleton

      sig { params(name: String, def_node: AST::Node, sig_nodes: T::Array[AST::Node], singleton: T::Boolean).void }
      def initialize(name, def_node, sig_nodes, singleton: false)
        @name = name
        @def_node = def_node
        @sig_nodes = sig_nodes
        @singleton = singleton
      end

      sig { returns(T::Boolean) }
      def has_sig?
        sig_nodes.any?
      end

      sig { params(other: Object).returns(Integer) }
      def <=>(other)
        return 0 unless other.is_a?(Method)
        name <=> other.name || 0
      end

      sig { returns(String) }
      def to_s
        str = String.new
        str << "self." if singleton
        str << name
        str << " (has sig)" if has_sig?
        str
      end
    end

    class Send
      extend T::Sig
      include Comparable

      sig { returns(String) }
      attr_reader :name

      sig { params(name: String).void }
      def initialize(name)
        @name = name
        @send_nodes = T.let([], T::Array[AST::Node])
      end

      sig { params(send_node: AST::Node).void }
      def add_send(send_node)
        @send_nodes << send_node
      end

      sig { returns(Integer) }
      def times
        @send_nodes.length
      end

      sig { params(other: Object).returns(Integer) }
      def <=>(other)
        return 0 unless other.is_a?(Send)
        other.times <=> times
      end

      sig { returns(String) }
      def to_s
        str = String.new
        str << name
        str << " (called #{times} times)"
        str
      end
    end

    class Collector
      extend T::Sig

      # opt-in to most recent AST format
      ::Parser::Builders::Default.emit_lambda               = true
      ::Parser::Builders::Default.emit_procarg0             = true
      ::Parser::Builders::Default.emit_encoding             = true
      ::Parser::Builders::Default.emit_index                = true
      ::Parser::Builders::Default.emit_arg_inside_procarg0  = true

      sig { void }
      def initialize
        @methods = T.let([], T::Array[Method])
        @sends = T.let({}, T::Hash[String, Send])
        @last_sigs = T.let([], T::Array[AST::Node])
      end

      sig { params(file: String).void }
      def collect_file(file)
        contents = File.read(file)
        node = ::Parser::CurrentRuby.parse(contents)
        visit(node)
      rescue ::Parser::SyntaxError => e
        raise "ParseError (#{e})"
        # raise ParseError.new(e.message, Loc.from_ast_loc(file, e.diagnostic.location))
      end

      EXCLUDED_SENDS = T.let([
        "include", "extend", "require", "require_relative", "private", "protected",
        "sig", "params", "returns", "void", "nilable", "unsafe", "let"
      ], T::Array[String])

      sig { void }
      def status
        puts "# Methods\n\n"
        @methods.sort.each { |method| puts " * #{method}" }
        puts "\n   Count: #{@methods.length}\n\n"

        puts "# Sends that could be typed\n\n"
        @sends.values
          .reject { |send| EXCLUDED_SENDS.include?(send.name) }
          .sort
          .each do |send|
            candidates = @methods.select { |method| method.name == send.name }
            next if candidates.any? && candidates.all?(&:has_sig?)
            line = String.new
            line << " * #{send}"
            line << " (candidates: #{candidates.join(', ')})" unless candidates.empty?
            puts line
          end
        puts "\n   Count: #{@sends.length}"
      end

      sig { params(nodes: T::Array[AST::Node]).void }
      def visit_all(nodes)
        nodes.each { |node| visit(node) }
      end

      sig { params(node: T.nilable(Object)).void }
      def visit(node)
        return unless node.is_a?(AST::Node)

        case node.type
        when :def
          visit_def(node)
        when :defs
          visit_defs(node)
        when :send
          visit_send(node)
        else
          visit_all(node.children)
        end
      end

      sig { params(node: AST::Node).void }
      def visit_def(node)
        name = node.children[0].to_s
        @methods << Method.new(name, node, @last_sigs.dup)
        @last_sigs.clear
        visit(node.children[2])
      end

      sig { params(node: AST::Node).void }
      def visit_defs(node)
        name = node.children[1].to_s
        @methods << Method.new(name, node, @last_sigs.dup, singleton: true)
        @last_sigs.clear
        visit(node.children[3])
      end

      sig { params(node: AST::Node).void }
      def visit_send(node)
        name = node.children[1].to_s
        @last_sigs << node if name == "sig"
        send_for_name(name).add_send(node)
        visit_all(node.children[2..])
      end

      sig { params(name: String).returns(Send) }
      def send_for_name(name)
        @sends[name] ||= Send.new(name)
      end
    end
  end
end
