# typed: strict
# frozen_string_literal: true

module Spoom
  # Build a file hierarchy from a set of file paths.
  class FileTree
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :strip_prefix

    sig { params(paths: T::Enumerable[String], strip_prefix: T.nilable(String)).void }
    def initialize(paths = [], strip_prefix: nil)
      @roots = T.let({}, T::Hash[String, Node])
      @strip_prefix = strip_prefix
      add_paths(paths)
    end

    # Add all `paths` to the tree
    sig { params(paths: T::Enumerable[String]).void }
    def add_paths(paths)
      paths.each { |path| add_path(path) }
    end

    # Add a `path` to the tree
    #
    # This will create all nodes until the root of `path`.
    sig { params(path: String).returns(Node) }
    def add_path(path)
      prefix = @strip_prefix
      path = path.delete_prefix("#{prefix}/") if prefix
      parts = path.split("/")
      if path.empty? || parts.size == 1
        return @roots[path] ||= Node.new(parent: nil, name: path)
      end
      parent_path = T.must(parts[0...-1]).join("/")
      parent = add_path(parent_path)
      name = T.must(parts.last)
      parent.children[name] ||= Node.new(parent: parent, name: name)
    end

    # All root nodes
    sig { returns(T::Array[Node]) }
    def roots
      @roots.values
    end

    # All the nodes in this tree
    sig { returns(T::Array[Node]) }
    def nodes
      all_nodes = []
      @roots.values.each { |root| collect_nodes(root, all_nodes) }
      all_nodes
    end

    # All the paths in this tree
    sig { returns(T::Array[String]) }
    def paths
      nodes.collect(&:path)
    end

    sig do
      params(
        out: T.any(IO, StringIO),
        show_strictness: T::Boolean,
        colors: T::Boolean,
        indent_level: Integer
      ).void
    end
    def print(out: $stdout, show_strictness: true, colors: true, indent_level: 0)
      printer = Printer.new(
        tree: self,
        out: out,
        show_strictness: show_strictness,
        colors: colors,
        indent_level: indent_level
      )
      printer.print_tree
    end

    private

    sig { params(node: FileTree::Node, collected_nodes: T::Array[Node]).returns(T::Array[Node]) }
    def collect_nodes(node, collected_nodes = [])
      collected_nodes << node
      node.children.values.each { |child| collect_nodes(child, collected_nodes) }
      collected_nodes
    end

    # A node representing either a file or a directory inside a FileTree
    class Node < T::Struct
      extend T::Sig

      # Node parent or `nil` if the node is a root one
      const :parent, T.nilable(Node)

      # File or dir name
      const :name, String

      # Children of this node (if not empty, it means it's a dir)
      const :children, T::Hash[String, Node], default: {}

      # Display path to this node from root (not including the tree prefix)
      sig { returns(String) }
      def path
        parent = self.parent
        return name unless parent
        "#{parent.path}/#{name}"
      end

      # Real path to this node (including the tree prefix)
      sig { params(tree: FileTree).returns(String) }
      def real_path(tree)
        prefix = tree.strip_prefix
        return "#{prefix}/#{path}" if prefix
        path
      end
    end

    # An abstract visitor for a FileTree
    class Visitor
      extend T::Helpers
      extend T::Sig

      abstract!

      sig { abstract.params(node: FileTree::Node).void }
      def visit_node(node); end

      sig { params(nodes: T::Array[FileTree::Node]).void }
      def visit_nodes(nodes)
        nodes.each { |node| visit_node(node) }
      end
    end

    # An internal class used to print a FileTree
    #
    # See `FileTree#print`
    class Printer < Spoom::Printer
      extend T::Sig

      sig { returns(FileTree) }
      attr_reader :tree

      sig do
        params(
          tree: FileTree,
          out: T.any(IO, StringIO),
          show_strictness: T::Boolean,
          colors: T::Boolean,
          indent_level: Integer
        ).void
      end
      def initialize(tree:, out: $stdout, show_strictness: true, colors: true, indent_level: 0)
        super(out: out, colors: colors, indent_level: indent_level)
        @tree = tree
        @show_strictness = show_strictness
        @strictnesses = T.let(Strictnesses.new(tree), T.nilable(Strictnesses)) if show_strictness
      end

      sig { void }
      def print_tree
        print_nodes(tree.roots)
      end

      sig { params(node: FileTree::Node).void }
      def print_node(node)
        printt
        if node.children.empty?
          strictness = @strictnesses&.node_strictness(node) if @show_strictness
          if @colors && strictness
            print_colored(node.name, strictness_color(strictness))
          elsif strictness
            print("#{node.name} (#{strictness})")
          else
            print(node.name.to_s)
          end
          print("\n")
        else
          print_colored(node.name, :blue)
          print("/")
          printn
          indent
          print_nodes(node.children.values)
          dedent
        end
      end

      sig { params(nodes: T::Array[FileTree::Node]).void }
      def print_nodes(nodes)
        nodes.each { |node| print_node(node) }
      end

      private

      sig { params(strictness: T.nilable(String)).returns(Symbol) }
      def strictness_color(strictness)
        case strictness
        when "false"
          :red
        when "true", "strict", "strong"
          :green
        else
          :uncolored
        end
      end
    end

    class Strictnesses < Visitor
      extend T::Sig

      sig { params(tree: FileTree).void }
      def initialize(tree)
        @tree = tree
        @strictnesses = T.let({}, T::Hash[FileTree::Node, T.nilable(String)])
        visit_nodes(tree.roots)
      end

      sig { override.params(node: FileTree::Node).void }
      def visit_node(node)
        if node.children.empty?
          path = node.real_path(@tree)
          @strictnesses[node] = Spoom::Sorbet::Sigils.file_strictness(path)
        else
          visit_nodes(node.children.values)
        end
      end

      sig { params(node: FileTree::Node).returns(T.nilable(String)) }
      def node_strictness(node)
        @strictnesses[node]
      end
    end
  end
end
