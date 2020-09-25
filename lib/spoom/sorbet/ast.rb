# typed: strict
# frozen_string_literal: true

module Spoom
  module Sorbet
    module AST

      class Node; end

      class ScopeDef < Node
        extend T::Sig

        sig { returns(Location) }
        attr_reader :loc

        sig { returns(Scope) }
        attr_reader :scope

        sig { returns(T.nilable(ScopeDef)) }
        attr_reader :parent_def

        sig { returns(T::Array[ScopeDef]) }
        attr_reader :children

        sig { returns(T::Array[IncludeDef]) }
        attr_reader :includes

        sig { returns(T::Array[ConstDef]) }
        attr_reader :consts

        sig { returns(T::Array[AttrDef]) }
        attr_reader :attrs

        sig { returns(T::Array[MethodDef]) }
        attr_reader :methods


        sig { params(loc: Location, scope: Scope, parent_def: T.nilable(ScopeDef)).void }
        def initialize(loc, scope, parent_def)
          @loc = loc
          @scope = scope
          @parent_def = parent_def
          @children = T.let([], T::Array[ScopeDef])
          @includes = T.let([], T::Array[IncludeDef])
          @consts = T.let([], T::Array[ConstDef])
          @attrs = T.let([], T::Array[AttrDef])
          @methods = T.let([], T::Array[MethodDef])
          parent_def.children << self if parent_def
          scope.defs << self
        end

        sig { returns(String) }
        def name
          @scope.name
        end

        sig { returns(String) }
        def qname
          @scope.qname
        end

        sig { returns(String) }
        def to_s
          qname
        end
      end

      class ModuleDef < ScopeDef
      end

      class ClassDef < ScopeDef
        extend T::Sig

        sig { returns(T.nilable(String)) }
        attr_reader :superclass_name

        sig { params(loc: Location, scope: Scope, parent_def: T.nilable(ScopeDef), superclass_name: T.nilable(String)).void }
        def initialize(loc, scope, parent_def, superclass_name = nil)
          super(loc, scope, parent_def)
          @superclass_name = superclass_name
        end
      end

      class PropertyDef < Node
        extend T::Sig

        sig { returns(Location) }
        attr_reader :loc

        sig { returns(ScopeDef) }
        attr_reader :scope_def

        sig { returns(Property) }
        attr_reader :property

        sig { returns(T.nilable(Sig)) }
        attr_reader :sorbet_sig

        sig do
          params(
            loc: Location,
            scope_def: ScopeDef,
            property: Property,
            sorbet_sig: T.nilable(Sig)
          ).void
        end
        def initialize(loc, scope_def, property, sorbet_sig)
          @loc = loc
          @scope_def = scope_def
          @property = property
          @sorbet_sig = sorbet_sig
          property.defs << self
        end

        sig { returns(String) }
        def name
          @property.name
        end
      end

      class AttrDef < PropertyDef
        extend T::Sig

        sig { returns(Symbol) }
        attr_reader :kind

        sig do
          params(
            loc: Location,
            scope_def: ScopeDef,
            property: Property,
            kind: Symbol,
            sorbet_sig: T.nilable(Sig)
          ).void
        end
        def initialize(loc, scope_def, property, kind, sorbet_sig)
          super(loc, scope_def, property, sorbet_sig)
          @kind = kind
          scope_def.attrs << self
        end
      end

      class ConstDef < PropertyDef
        extend T::Sig

        sig do
          params(
            loc: Location,
            scope_def: ScopeDef,
            property: Property,
            sorbet_sig: T.nilable(Sig)
          ).void
        end
        def initialize(loc, scope_def, property, sorbet_sig)
          super(loc, scope_def, property, sorbet_sig)
          scope_def.consts << self
        end
      end

      class MethodDef < PropertyDef
        extend T::Sig

        sig { returns(T::Boolean) }
        attr_reader :is_singleton

        sig { returns(T::Array[Param]) }
        attr_reader :params

        sig do
          params(
            loc: Location,
            scope_def: ScopeDef,
            property: Property,
            is_singleton: T::Boolean,
            params: T::Array[Param],
            sorbet_sig: T.nilable(Sig)
          ).void
        end
        def initialize(loc, scope_def, property, is_singleton, params, sorbet_sig)
          super(loc, scope_def, property, sorbet_sig)
          @is_singleton = is_singleton
          @params = params
          scope_def.methods << self
        end
      end

      class IncludeDef < Node
        extend T::Sig

        sig { returns(ScopeDef) }
        attr_reader :scope_def

        sig { returns(Symbol) }
        attr_reader :kind

        sig { returns(String) }
        attr_reader :name

        sig { params(scope_def: ScopeDef, name: String, kind: Symbol).void }
        def initialize(scope_def, name, kind)
          @scope_def = scope_def
          @name = name
          @kind = kind
          scope_def.includes << self
        end
      end

      class BuildScopes
        extend T::Sig

        sig { params(source: SourceFile).void }
        def self.run(source)
          phase = BuildScopes.new(source)
          phase.visit(source.tree)
        end

        sig { params(source: SourceFile).void }
        def initialize(source)
          @source = source
          root_def = make_root_def
          source.root_def = root_def
          @stack = T.let([root_def], T::Array[ScopeDef])
          @last_sig = T.let(nil, T.nilable(Sorbet::Sig))
        end

        sig { params(node: T.nilable(Object)).void }
        def visit(node)
          # return unless node.is_a?(::Parser::AST::Node)

          case node.type
          when :module
            visit_module(node)
          when :class
            visit_class(node)
          when :def
            visit_def(node)
          when :defs
            visit_defs(node)
          when :casgn
            visit_const_assign(node)
          when :send
            visit_send(node)
          else
            visit_all(node.children)
          end
        end

        sig { params(nodes: T::Array[AST::Node]).void }
        def visit_all(nodes)
          nodes.each { |node| visit(node) }
        end

        private

        sig { returns(Model::ModuleDef) }
        def make_root_def
          ModuleDef.new(Location.new(@source.path, Position.new(0, 0)), nil)
        end

        # Scopes

        sig { params(node: AST::Node).void }
        def visit_module(node)
          last = T.must(@stack.last)
          # name = visit_name(node.children.first)
          # qname = Scope.qualify_name(last.scope, name)

          loc = Location.from_node(@source.path, node)
          mod_def = ModuleDef.new(loc, last)

          @stack << mod_def
          visit_all(node.children)
          @stack.pop
          @last_sig = nil
        end

        sig { params(node: AST::Node).void }
        def visit_class(node)
          last = T.must(@stack.last)
          # name = visit_name(node.children.first)
          # qname = Model::Scope.qualify_name(last.scope, name)

          loc = Location.from_node(@source.path, node)
          superclass = visit_name(node.children[1]) if node.children[1]
          class_def = Model::ClassDef.new(loc, last, superclass)

          @stack << class_def
          visit_all(node.children)
          @stack.pop
          @last_sig = nil
        end

        # Properties

        sig { params(node: AST::Node).void }
        def visit_attr(node)
          last = T.must(@stack.last)
          kind = node.children[1]

          node.children[2..-1].each do |child|
            # name = child.children.first.to_s
            # qname = Model::Attr.qualify_name(last.scope, name)

            loc = Location.from_node(@source.path, node)
            Model::AttrDef.new(loc, last, kind, @last_sig)
          end
          @last_sig = nil
        end

        sig { params(node: AST::Node).void }
        def visit_const_assign(node)
          last = T.must(@stack.last)
          # name = node.children[1].to_s
          # qname = Model::Const.qualify_name(last.scope, name)

          loc = Location.from_node(@source.path, node)
          Model::ConstDef.new(loc, last, nil)
          @last_sig = nil
        end

        sig { params(node: AST::Node).void }
        def visit_def(node)
          last = T.must(@stack.last)
          # name = node.children.first
          # qname = Model::Method.qualify_name(last.scope, name.to_s, false)

          loc = Location.from_node(@source.path, node)
          params = node.children[1].children.map { |n| Model::Param.new(n.children.first.to_s) } if node.children[1]
          Model::MethodDef.new(loc, last, false, params, @last_sig)
          @last_sig = nil
        end

        sig { params(node: AST::Node).void }
        def visit_defs(node)
          last = T.must(@stack.last)
          # name = node.children[1]
          # qname = Model::Method.qualify_name(last.scope, name.to_s, true)

          loc = Location.from_node(@source.path, node)
          params = node.children[2].children.map { |n| Model::Param.new(n.children.first.to_s) } if node.children[2]
          Model::MethodDef.new(loc, last, true, params, @last_sig)
          @last_sig = nil
        end

        sig { params(node: AST::Node).void }
        def visit_send(node)
          case node.children[1]
          when :attr_reader, :attr_writer, :attr_accessor
            visit_attr(node)
          when :include, :prepend, :extend
            visit_include(node)
          when :sig
            visit_sig(node)
          end
        end

        sig { params(node: AST::Node).void }
        def visit_include(node)
          last = T.must(@stack.last)
          return unless node.children[2] # TODO
          name = visit_name(node.children[2])
          kind = node.children[1]
          IncludeDef.new(last, name, kind)
        end

        sig { params(node: AST::Node).void }
        def visit_sig(node)
          if @last_sig
            # TODO: print error
            puts "error: already in a sig"
          end
          @last_sig = Sig.new
        end

        # Utils

        sig { params(node: AST::Node).returns(String) }
        def visit_name(node)
          v = ScopeNameVisitor.new
          v.visit(node)
          v.names.join("::")
        end

        sig { returns(String) }
        def current_namespace
          T.must(@stack.last).qname
        end
      end

      class ScopeNameVisitor
        extend T::Sig

        sig { returns(T::Array[String]) }
        attr_accessor :names

        sig { void }
        def initialize
          @names = T.let([], T::Array[String])
        end

        sig { params(node: T.nilable(Object)).void }
        def visit(node)
          return unless node.is_a?(::Parser::AST::Node)
          node.children.each { |child| visit(child) }
          names << node.location.name.source if node.type == :const
        end
      end
    end

    class Location
      extend T::Sig

      sig { params(file: T.nilable(String), node: AST::Node).returns(Location) }
      def self.from_node(file, node)
        loc = node.location
        Location.new(file, Range.new(Position.new(loc.line, loc.column), Position.new(loc.last_line, loc.last_column)))
      end
    end

  end
end
