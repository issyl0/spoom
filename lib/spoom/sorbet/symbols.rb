# typed: strict
# frozen_string_literal: true

module Spoom
  module Sorbet
    class Symbol
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(String) }
      attr_reader :name, :qname

      sig { params(name: String, qname: String).void }
      def initialize(name, qname)
        @name = name
        @qname = qname
      end
    end

    class Scope < Symbol
      extend T::Sig

      sig { returns(T.nilable(Scope)) }
      attr_reader :parent

      sig { returns(T::Array[Scope]) }
      attr_reader :children

      sig { returns(T::Array[AST::ScopeDef]) }
      attr_reader :defs

      sig { returns(T::Array[Include]) }
      attr_reader :includes

      sig { returns(T::Array[Const]) }
      attr_reader :consts

      sig { returns(T::Array[Attr]) }
      attr_reader :attrs

      sig { returns(T::Array[Method]) }
      attr_reader :methods

      sig { params(parent: T.nilable(Scope), name: String, qname: String).void }
      def initialize(parent, name, qname)
        super(name, qname)
        @parent = parent
        @children = T.let([], T::Array[Scope])
        @defs = T.let([], T::Array[AST::ScopeDef])
        @includes = T.let([], T::Array[Include])
        @attrs = T.let([], T::Array[Attr])
        @consts = T.let([], T::Array[Const])
        @methods = T.let([], T::Array[Method])
        parent.children << self if parent
      end

      sig { returns(T::Boolean) }
      def root?
        @parent.nil?
      end

      sig { returns(String) }
      def to_s
        qname
      end

      sig { params(parent: T.nilable(Scope), name: String).returns(String) }
      def self.qualify_name(parent, name)
        return "<root>" if !parent && name == "<root>" # TODO: yakk..
        return "#{parent.qname}::#{name}" if parent && !parent.root?
        "::#{name}"
      end
    end

    class Include < Symbol
      extend T::Sig

      sig { returns(Sorbet::Module) }
      attr_reader :mod

      sig { returns(Symbol) }
      attr_reader :kind

      sig { params(mod: Sorbet::Module, kind: Symbol).void }
      def initialize(mod, kind)
        @mod = mod
        @kind = kind
      end
    end

    class Module < Scope
    end

    class Class < Scope
      extend T::Sig

      sig { returns(T.nilable(Sorbet::Class)) }
      attr_accessor :superclass

      sig { params(parent: T.nilable(Scope), name: String, qname: String).void }
      def initialize(parent, name, qname)
        super(parent, name, qname)
      end
    end

    class Property < Symbol
      extend T::Sig

      sig { returns(Scope) }
      attr_reader :scope

      sig { returns(T::Array[AST::PropertyDef]) }
      attr_reader :defs

      sig { params(scope: Scope, name: String, qname: String).void }
      def initialize(scope, name, qname)
        super(name, qname)
        @scope = scope
        @defs = T.let([], T::Array[AST::PropertyDef])
      end
    end

    class Attr < Property
      extend T::Sig

      sig { returns(Symbol) }
      attr_reader :kind

      sig { params(scope: Sorbet::Scope, name: String, qname: String, kind: Symbol).void }
      def initialize(scope, name, qname, kind)
        super(scope, name, qname)
        @kind = kind
        scope.attrs << self
      end

      sig { params(scope: T.nilable(Scope), name: String).returns(String) }
      def self.qualify_name(scope, name)
        return "@#{name}" unless scope
        "#{scope.qname}@#{name}"
      end
    end

    class Const < Property
      extend T::Sig

      sig { params(scope: Scope, name: String, qname: String).void }
      def initialize(scope, name, qname)
        super(scope, name, qname)
        scope.consts << self
      end

      sig { params(scope: T.nilable(Scope), name: String).returns(String) }
      def self.qualify_name(scope, name)
        return "::#{name}" unless scope
        "#{scope.qname}::#{name}"
      end
    end

    class Method < Property
      extend T::Sig

      sig { returns(T::Boolean) }
      attr_reader :is_singleton

      # sig { returns(T::Array[Param]) }
      # attr_reader :params

      sig { params(scope: Scope, name: String, qname: String, is_singleton: T::Boolean).void }
      def initialize(scope, name, qname, is_singleton)
        super(scope, name, qname)
        @is_singleton = is_singleton
        scope.methods << self
      end

      sig { params(scope: T.nilable(Scope), name: String, is_singleton: T::Boolean).returns(String) }
      def self.qualify_name(scope, name, is_singleton)
        label = is_singleton ? "::" : "#"
        return "#{label}#{name}" unless scope
        "#{scope.qname}#{label}#{name}"
      end
    end

    class Param < Symbol
      extend T::Sig

      sig { returns(String) }
      attr_reader :name

      sig { params(name: String).void }
      def initialize(name)
        @name = name
      end

      sig { returns(String) }
      def to_s
        @name
      end
    end

    class Sig < Symbol
    end
  end
end
