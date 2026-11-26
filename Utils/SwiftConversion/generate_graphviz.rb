#!/usr/bin/env ruby

require 'json'
require 'set'

class GraphvizGenerator
  def initialize(analysis_file = 'objc_conversion_analysis.json')
    @data = JSON.parse(File.read(analysis_file))
    @ready_files = @data['ready_for_conversion']
    @waiting_files = @data['waiting_for_dependencies']
    @dependencies = @data['dependencies']
    @reverse_dependencies = @data['reverse_dependencies']
    @class_to_file_map = @data['class_to_file_map']
    @protocol_to_file_map = @data['protocol_to_file_map']
    @all_files = (@ready_files + @waiting_files).map { |f| f['file'] }.uniq
  end

  def generate_dot_file
    puts "🔍 Generating Graphviz DOT file..."
    
    dot_content = generate_dot_content
    File.write('objc_dependencies_topo.dot', dot_content)
    puts "✅ Generated objc_dependencies_topo.dot"
  end

  private

  def compute_in_degrees
    in_degrees = Hash.new(0)
    @all_files.each { |f| in_degrees[f] = 0 }
    @dependencies.each do |file, deps|
      deps.each do |dep|
        dep_file = @class_to_file_map[dep] || @protocol_to_file_map[dep]
        if dep_file && dep_file != file
          in_degrees[file] += 1
        end
      end
    end
    in_degrees
  end

  def generate_dot_content
    in_degrees = compute_in_degrees
    <<~DOT
      digraph ObjCDependenciesTopo {
        rankdir=TB;
        node [shape=box, style=filled, fontname="Arial", fontsize=10];
        edge [fontname="Arial", fontsize=8];

        // Nodes
        #{generate_nodes_with_in_degree(in_degrees)}

        // Edges
        #{generate_edges}

        // Legend
        subgraph cluster_legend {
          label="Legend";
          style=filled;
          color=lightgrey;
          ready_legend [label="Ready to convert (no parents)", style=filled, fillcolor=lightgreen];
          waiting_legend [label="Waiting for dependencies", style=filled, fillcolor=orange];
          high_impact_legend [label=">10 dependents", style=filled, fillcolor=red, fontcolor=white];
        }
      }
    DOT
  end

  def generate_nodes_with_in_degree(in_degrees)
    nodes = []
    (@ready_files + @waiting_files).each do |file|
      next if in_degrees[file['file']] == 0 and file['dependents_count'] == 0
      color =
        if in_degrees[file['file']] == 0
          'lightgreen'
        elsif file['dependents_count'] > 10
          'red'
        else
          'orange'
        end
      nodes << "  \"#{file['file']}\" [label=\"#{file['file']}\\n(#{file['dependents_count']} deps)\", fillcolor=\"#{color}\"];"
    end
    nodes.join("\n")
  end

  def generate_edges
    edges = []
    @dependencies.each do |file, deps|
      deps.each do |dep|
        dep_file = @class_to_file_map[dep] || @protocol_to_file_map[dep]
        if dep_file && dep_file != file
          edges << "  \"#{dep_file}\" -> \"#{file}\";"
        end
      end
    end
    edges.join("\n")
  end
end

if __FILE__ == $0
  generator = GraphvizGenerator.new
  generator.generate_dot_file
end 
