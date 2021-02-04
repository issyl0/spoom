# typed: strict
# frozen_string_literal: true

require_relative "base"

module Spoom
  module Coverage
    module D3
      class CircleMap < Base
        extend T::Sig

        sig { returns(String) }
        def self.header_style
          <<~CSS
            .node {
              cursor: pointer;
            }

            .node:hover {
              stroke: #333;
              stroke-width: 1px;
            }

            .label.dir {
              fill: #333;
            }

            .label.file {
              font: 12px Arial, sans-serif;
            }

            .node.root, .node.file {
              pointer-events: none;
            }

            .select-score {
              position: absolute;
              top: 80px;
              right: 30px;
            }
          CSS
        end

        sig { returns(String) }
        def self.header_script
          <<~JS
            function treeHeight(root, height = 0) {
              height += 1;
              if (root.children && root.children.length > 0)
                return Math.max(...root.children.map(child => treeHeight(child, height)));
              else
                return height;
            }

            function treeMax(root, key, max = 0) {
              max = Math.max(root[key] || 0, max);
              if (root.children && root.children.length > 0)
                return Math.max(...root.children.map(child => treeMax(child, key, max)));
              else
                return max;
            }

            function tooltipMap(d) {
              moveTooltip(d)
                .html("<b>" + d.data.name + "</b>")
            }
          JS
        end

        sig { override.returns(String) }
        def script
          <<~JS
            var dataRoot = {children: #{@data.to_json}}
            var dataHeight = treeHeight(dataRoot)

            var opacity = d3.scaleLinear()
                .domain([0, dataHeight])
                .range([0, 0.2])

            root = d3.hierarchy(dataRoot)
                .sum((d) => d.children ? d.children.length : 1)
                .sort((a, b) => b.value - a.value);

            var dirColor = d3.scaleLinear()
              .domain([1, 0])
              .range([strictnessColor("true"), strictnessColor("false")])
              .interpolate(d3.interpolateRgb);

            var unsafeColor = d3.scaleLinear()
              .domain([0, treeMax(dataRoot, "tunsafe_score")])
              .range([strictnessColor("true"), strictnessColor("false")])
              .interpolate(d3.interpolateRgb);

            function nodeColor(d) {
              var key = document.getElementById("#{id}").score_key;
              console.log(key);
              console.log(d.data);
              if (d.children) {
                return dirColor(d.data[key]);
              } else {
                if (key == "sigils_score") {
                  return strictnessColor(d.data.strictness);
                } else {
                  return unsafeColor(d.data.tunsafe_score);
                }
              }
            }

            function redraw() {
              var diameter = document.getElementById("#{id}").clientWidth - 20;
              d3.select("##{id}").selectAll("*").remove()

              var svg_#{id} = d3.select("##{id}")
                .attr("width", diameter)
                .attr("height", diameter)
                .append("g")
                  .attr("transform", "translate(" + diameter / 2 + "," + diameter / 2 + ")");

              var pack = d3.pack()
                  .size([diameter, diameter])
                  .padding(2);

              var focus = root,
                  nodes = pack(root).descendants(),
                  view;

              var circle = svg_#{id}.selectAll("circle")
                .data(nodes)
                .enter().append("circle")
                  .attr("class", (d) => d.parent ? d.children ? "node" : "node file" : "node root")
                  .attr("fill", (d) => nodeColor(d))
                  .attr("fill-opacity", (d) => d.children ? opacity(d.depth) : 1)
                  .on("click", function(d) { if (focus !== d) zoom(d), d3.event.stopPropagation(); })
                  .on("mouseover", (d) => tooltip.style("opacity", 1))
                  .on("mousemove", tooltipMap)
                  .on("mouseleave", (d) => tooltip.style("opacity", 0));

              var text = svg_#{id}.selectAll("text")
                .data(nodes)
                .enter().append("text")
                  .attr("class", (d) => d.children ? "label dir" : "label file")
                  .attr("fill-opacity", (d) => d.depth <= 1 ? 1 : 0)
                  .attr("display", (d) => d.depth <= 1 ? "inline" : "none")
                  .text((d) => d.data.name);

              var node = svg_#{id}.selectAll("circle,text");

              function zoom(d) {
                var focus0 = focus; focus = d;

                var transition = d3.transition()
                    .duration(d3.event.altKey ? 7500 : 750)
                    .tween("zoom", function(d) {
                      var i = d3.interpolateZoom(view, [focus.x, focus.y, focus.r * 2]);
                      return (t) => zoomTo(i(t));
                    });

                transition.selectAll("text")
                  .filter(function(d) { return d && d.parent === focus || this.style.display === "inline"; })
                    .attr("fill-opacity", function(d) { return d.parent === focus ? 1 : 0; })
                    .on("start", function(d) { if (d.parent === focus) this.style.display = "inline"; })
                    .on("end", function(d) { if (d.parent !== focus) this.style.display = "none"; });
              }

              function zoomTo(v) {
                var k = diameter / v[2]; view = v;
                node.attr("transform", (d) => "translate(" + (d.x - v[0]) * k + "," + (d.y - v[1]) * k + ")");
                circle.attr("r", (d) => d.r * k);
              }

              zoomTo([root.x, root.y, root.r * 2]);
              d3.select("##{id}").on("click", () => zoom(root));
            }

            function selectScore(e) {
              document.getElementById("#{id}").score_key = e.target.value;
              redraw();
            }
            document.getElementById("#{id}").score_key = "sigils_score";

            optSigils = document.createElement("option");
            optSigils.value = "sigils_score";
            optSigils.text = "Sigils";

            optTUnsafes = document.createElement("option");
            optTUnsafes.value = "tunsafe_score";
            optTUnsafes.text = "T.unsafe";

            opt = document.createElement("select");
            opt.className = "select-score"
            opt.appendChild(optSigils);
            opt.appendChild(optTUnsafes);
            opt.addEventListener("change", selectScore)

            document.getElementById("#{id}").parentElement.appendChild(opt)

            redraw();
            window.addEventListener("resize", redraw);
          JS
        end

        class FileMap < CircleMap
          extend T::Sig

          sig { params(id: String, tree: FileTree).void }
          def initialize(id, tree)
            @strictnesses = T.let(FileTree::Strictnesses.new(tree), FileTree::Strictnesses)
            @sigils_scores = T.let(SigilsScore.new(tree, @strictnesses), SigilsScore)
            @tunsafe_scores = T.let(TUnsafeScore.new(tree, @strictnesses), TUnsafeScore)
            super(id, tree.roots.map { |r| tree_node_to_json(r) })
          end

          sig { params(node: FileTree::Node).returns(T::Hash[Symbol, T.untyped]) }
          def tree_node_to_json(node)
            if node.children.empty?
              return {
                name: node.name,
                strictness: @strictnesses.node_strictness(node),
                tunsafe_score: @tunsafe_scores.node_score(node),
              }
            end
            {
              name: node.name,
              children: node.children.values.map { |n| tree_node_to_json(n) },
              sigils_score: @sigils_scores.node_score(node),
              tunsafe_score: @tunsafe_scores.node_score(node),
            }
          end
        end

        class SigilsScore < FileTree::Visitor
          extend T::Sig

          sig { params(tree: FileTree, strictnesses: FileTree::Strictnesses).void }
          def initialize(tree, strictnesses)
            @tree = tree
            @strictnesses = strictnesses
            @scores = T.let({}, T::Hash[FileTree::Node, Float])
            visit_nodes(tree.roots)
          end

          sig { override.params(node: FileTree::Node).void }
          def visit_node(node)
            unless node.children.empty?
              visit_nodes(node.children.values)
              @scores[node] = node.children.values.sum { |n| @scores[n] || 0.0 } / node.children.size.to_f
              return
            end

            case @strictnesses.node_strictness(node)
            when "true", "strict", "strong"
              @scores[node] = 1.0
              return
            end
          end

          sig { params(node: FileTree::Node).returns(Float) }
          def node_score(node)
            @scores[node] || 0.0
          end
        end

        class TUnsafeScore < FileTree::Visitor
          extend T::Sig

          sig { params(tree: FileTree, strictnesses: FileTree::Strictnesses).void }
          def initialize(tree, strictnesses)
            @tree = tree
            @scores = T.let({}, T::Hash[FileTree::Node, Float])
            visit_nodes(tree.roots)
          end

          sig { override.params(node: FileTree::Node).void }
          def visit_node(node)
            unless node.children.empty?
              visit_nodes(node.children.values)
              @scores[node] = node.children.values.sum { |n| @scores[n] || 0.0 } / node.children.size.to_f
              return
            end

            @scores[node] = Sorbet::TUnsafe.t_unsafes_in_file(node.real_path(@tree)).to_f
          end

          sig { params(node: FileTree::Node).returns(Float) }
          def node_score(node)
            @scores[node] || 0.0
          end
        end
      end
    end
  end
end
