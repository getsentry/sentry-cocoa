#!/usr/bin/env ruby

require 'set'
require 'json'

class ObjCConversionAnalyzer
  def initialize(include_dir = '../Sources/Sentry/include')
    @include_dir = include_dir
    @header_files = []
    @dependencies = {}
    @reverse_dependencies = {}
    @class_to_file_map = {}
    @protocol_to_file_map = {}
    @file_to_classes_map = {}
    @file_to_protocols_map = {}
  end

  def analyze
    puts "🔍 Analyzing Objective-C header files in #{@include_dir}..."
    
    # Find all header files
    find_header_files
    
    # Parse each header file
    parse_header_files
    
    # Build dependency graph
    build_dependency_graph
    
    # Analyze conversion readiness
    analyze_conversion_readiness
    
    # Generate report
    generate_report
  end

  private

  def find_header_files
    Dir.glob(File.join(@include_dir, '**/*.h')).each do |file|
      next if file.include?('.DS_Store') or file.include?('+')
      @header_files << file
    end
    puts "📁 Found #{@header_files.length} header files"
  end

  def parse_header_files
    @header_files.each do |file|
      parse_header_file(file)
    end
  end

  def parse_header_file(file_path)
    content = File.read(file_path)
    relative_path = file_path.sub(@include_dir + '/', '')
    
    # Extract class declarations
    classes = extract_classes(content)
    protocols = extract_protocols(content)
    dependencies = extract_dependencies(content)
    
    # Map classes and protocols to files
    classes.each do |class_name|
      @class_to_file_map[class_name] = relative_path
    end
    
    protocols.each do |protocol_name|
      @protocol_to_file_map[protocol_name] = relative_path
    end
    
    @file_to_classes_map[relative_path] = classes
    @file_to_protocols_map[relative_path] = protocols
    @dependencies[relative_path] = dependencies
  end

  def extract_classes(content)
    classes = []
    
    # Look for @interface declarations
    content.scan(/@interface\s+(\w+)/).each do |match|
      classes << match[0]
    end
    
    classes.uniq
  end

  def extract_protocols(content)
    protocols = []
    
    # Look for @protocol declarations
    content.scan(/@protocol\s+(\w+)/).each do |match|
      protocols << match[0]
    end
    
    protocols.uniq
  end

  def extract_dependencies(content)
    dependencies = Set.new
    
    # Extract @class dependencies
    content.scan(/@class\s+(\w+)/).each do |match|
      class_name = match[0]
      dependencies << class_name
    end
    
    # Extract @protocol dependencies
    content.scan(/@protocol\s+(\w+)/).each do |match|
      protocol_name = match[0]
      dependencies << protocol_name
    end
    
    dependencies.to_a
  end

  def build_dependency_graph
    @dependencies.each do |file, deps|
      @reverse_dependencies[file] = Set.new
    end
    
    @dependencies.each do |file, deps|
      deps.each do |dep|
        # Check if dependency is implemented in our header files
        if @class_to_file_map[dep] || @protocol_to_file_map[dep]
          dep_file = @class_to_file_map[dep] || @protocol_to_file_map[dep]
          if dep_file != file # Avoid self-dependencies
            @reverse_dependencies[dep_file] << file
          end
        end
      end
    end
  end

  def analyze_conversion_readiness
    @ready_for_conversion = []
    @waiting_for_dependencies = []
    
    @header_files.each do |file_path|
      relative_path = file_path.sub(@include_dir + '/', '')
      deps = @dependencies[relative_path] || []
      
      # Check if all dependencies are external (not in our header files)
      external_deps = deps.select { |dep| !@class_to_file_map[dep] && !@protocol_to_file_map[dep] }
      
      if external_deps.length == deps.length
        # All dependencies are external, ready for conversion
        @ready_for_conversion << {
          file: relative_path,
          dependencies: deps,
          dependents_count: @reverse_dependencies[relative_path]&.length || 0
        }
      else
        # Has internal dependencies, waiting
        internal_deps = deps.select { |dep| @class_to_file_map[dep] || @protocol_to_file_map[dep] }
        @waiting_for_dependencies << {
          file: relative_path,
          dependencies: deps,
          internal_dependencies: internal_deps,
          dependents_count: @reverse_dependencies[relative_path]&.length || 0
        }
      end
    end
  end

  def generate_report
    puts "\n" + "="*80
    puts "📊 OBJECTIVE-C TO SWIFT CONVERSION ANALYSIS"
    puts "="*80
    
    puts "\n🎯 READY FOR CONVERSION (#{@ready_for_conversion.length} files)"
    puts "-" * 50
    
    # Sort by number of dependents (highest first)
    ready_sorted = @ready_for_conversion.sort_by { |item| -item[:dependents_count] }
    
    ready_sorted.each do |item|
      puts "📄 #{item[:file]}"
      puts "   Dependents: #{item[:dependents_count]}"
      puts "   Dependencies: #{item[:dependencies].join(', ')}" unless item[:dependencies].empty?
      puts
    end
    
    puts "\n⏳ WAITING FOR DEPENDENCIES (#{@waiting_for_dependencies.length} files)"
    puts "-" * 50
    
    # Save detailed data to JSON
    save_detailed_data
  end

  def save_detailed_data
    data = {
      ready_for_conversion: @ready_for_conversion,
      waiting_for_dependencies: @waiting_for_dependencies,
      dependencies: @dependencies,
      reverse_dependencies: @reverse_dependencies.transform_values(&:to_a),
      class_to_file_map: @class_to_file_map,
      protocol_to_file_map: @protocol_to_file_map,
      file_to_classes_map: @file_to_classes_map,
      file_to_protocols_map: @file_to_protocols_map
    }
    
    File.write('objc_conversion_analysis.json', JSON.pretty_generate(data))
    puts "\n💾 Detailed analysis saved to objc_conversion_analysis.json"
  end
end

# Run the analysis
if __FILE__ == $0
  analyzer = ObjCConversionAnalyzer.new
  analyzer.analyze
end 
