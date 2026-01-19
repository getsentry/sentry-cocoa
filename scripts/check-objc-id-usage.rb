# frozen_string_literal: true

# Checks Objective-C header files for bare 'id' usage without SENTRY_SWIFT_MIGRATION_ID macro.
#
# During Swift migration, bare 'id' types should be annotated with SENTRY_SWIFT_MIGRATION_ID(ClassName)
# to track temporary workarounds and make them easy to find later.
#
# This linter flags any 'id' usage in .h files that:
# - Is not part of SENTRY_SWIFT_MIGRATION_ID macro
# - Is not in a comment
# - Does not have an inline comment explaining why bare 'id' is needed
#
# Allowed patterns:
# 1. SENTRY_SWIFT_MIGRATION_ID(ClassName)
# 2. id someVar; // OK: explanation why bare id is needed
# 3. id someVar; /* OK: explanation */

require 'optparse'
require 'pathname'

module ExitStatus
  SUCCESS = 0
  VIOLATIONS_FOUND = 1
  TROUBLE = 2
end

def bold_red(str)
  "\e[1m\e[31m#{str}\e[0m"
end

def yellow(str)
  "\e[33m#{str}\e[0m"
end

def list_files(files, recursive: false, extensions: [], exclude: [])
  out = []

  files.each do |file|
    if recursive && File.directory?(file)
      Dir.glob(File.join(file, '**', '*')).each do |path|
        next unless File.file?(path)

        # Check exclusions
        excluded = exclude.any? { |pattern| File.fnmatch?(pattern, path) }
        next if excluded

        # Check extension
        ext = File.extname(path)[1..-1]
        out << path if extensions.include?(ext)
      end
    else
      out << file
    end
  end

  out
end

def remove_comments(code)
  lines = code.split("\n")
  result_lines = []
  in_multiline_comment = false

  lines.each do |line|
    result = ''
    pos = 0

    while pos < line.length
      if in_multiline_comment
        # Look for end of multi-line comment
        end_pos = line.index('*/', pos)
        if end_pos
          # Found end of multi-line comment
          result += ' ' * (end_pos + 2 - pos)
          pos = end_pos + 2
          in_multiline_comment = false
        else
          # Rest of line is still in comment
          result += ' ' * (line.length - pos)
          break
        end
      else
        # Look for the first comment marker (/* or //)
        block_start = line.index('/*', pos)
        line_comment = line.index('//', pos)

        # Determine which comes first
        if block_start && (!line_comment || block_start < line_comment)
          # Block comment starts first
          result += line[pos...block_start]

          # Look for end of block comment on same line
          end_pos = line.index('*/', block_start + 2)
          if end_pos
            # Block comment ends on same line
            result += ' ' * (end_pos + 2 - block_start)
            pos = end_pos + 2
          else
            # Block comment continues to next line
            result += ' ' * (line.length - block_start)
            in_multiline_comment = true
            break
          end
        elsif line_comment
          # Line comment starts first (or is the only comment)
          result += line[pos...line_comment]
          # Rest of line is comment, stop processing
          break
        else
          # No more comments on this line
          result += line[pos..-1]
          break
        end
      end
    end

    result_lines << result
  end

  result_lines.join("\n")
end

def has_inline_comment_exception?(line)
  # Check for // OK: comment
  return true if line =~ %r{//\s*OK:}i
  # Check for /* OK: comment */
  return true if line =~ %r{/\*\s*OK:.*?\*/}i
  false
end

def has_comment_on_continuation_lines?(lines, start_line_num)
  # Check if a multi-line declaration has an OK: comment on any line up to and including the semicolon.
  #
  # For method declarations that span multiple lines, checks from start_line_num onwards
  # until we find a semicolon, looking for an inline comment exception.
  #
  # Args:
  #   lines: Array of all lines in the file (original, with comments)
  #   start_line_num: 1-based line number where the declaration starts
  #
  # Returns:
  #   true if an OK: comment is found on any continuation line, false otherwise

  # Convert to 0-based index
  idx = start_line_num - 1

  while idx < lines.length
    current_line = lines[idx]

    # Check if this line has the OK: comment
    return true if has_inline_comment_exception?(current_line)

    # Check if this line ends the declaration (contains semicolon)
    break if current_line.include?(';')

    idx += 1
  end

  false
end

def check_id_usage(file_path)
  # Check a single header file for bare 'id' usage.
  #
  # Returns an array of violations, where each violation is [line_number, line_content]
  violations = []

  begin
    content = File.read(file_path, encoding: 'utf-8')
    lines = content.lines.map(&:chomp)
  rescue SystemCallError, IOError => e
    warn "Error reading #{file_path}: #{e}"
    return violations
  end

  # Remove comments for main analysis, but keep original lines for inline comment check
  content_no_comments = remove_comments(content)
  lines_no_comments = content_no_comments.lines.map(&:chomp)

  # Pattern to match bare 'id' usage that should use SENTRY_SWIFT_MIGRATION_ID:
  # Match 'id' as a type in declarations:
  # - @property declarations: @property (nonatomic, strong) id variableName
  # - Parameter types in method signatures: - (void)method:(id)param
  # - Return types: - (id)method or + (id)method
  # - Instance variable declarations: id _ivar;
  #
  # Exclusions:
  # - id<Protocol> (protocol conformance) - handled by (?!\s*<) negative lookahead in each pattern
  # - String literals containing "id"
  # - Already using SENTRY_SWIFT_MIGRATION_ID
  # - initializers

  lines.each_with_index do |line, idx|
    line_num = idx + 1
    line_no_comment = lines_no_comments[idx]

    # Skip if line_no_comment is nil or empty
    next if line_no_comment.nil? || line_no_comment.strip.empty?

    # Skip if SENTRY_SWIFT_MIGRATION_ID is already used on this line
    next if line_no_comment.include?('SENTRY_SWIFT_MIGRATION_ID')

    # Skip if this is a string literal (rough check)
    next if line_no_comment.include?('"id"') || line_no_comment.include?("'id'")

    # Note: We don't skip lines containing id<Protocol> here because:
    # 1. All detection patterns already use (?!\s*<) negative lookahead to exclude id<Protocol>
    # 2. A line might contain both bare 'id' and 'id<Protocol>' (e.g., - (id)methodWithDelegate:(id<SomeDelegate>)delegate;)
    #    and we need to detect the bare 'id' violation

    # Check for various patterns where bare 'id' is used as a type:

    # Pattern 1: @property declarations with bare id
    # @property (...) id propertyName
    if line_no_comment =~ /@property\s*\([^)]*\)\s*\bid\b(?!\s*<)/
      unless has_inline_comment_exception?(line) || has_comment_on_continuation_lines?(lines, line_num)
        violations << [line_num, line.rstrip]
        next
      end
    end

    # Pattern 2: Method return type: - (id)methodName or + (id)methodName
    # Skip init methods as returning id from init is idiomatic Objective-C
    if line_no_comment =~ /^[+-]\s*\(\s*\bid\b(?!\s*<)\s*\)/
      # Check if this is an init method
      unless line_no_comment =~ /^[+-]\s*\(\s*id\s*\)\s*init/
        unless has_inline_comment_exception?(line) || has_comment_on_continuation_lines?(lines, line_num)
          violations << [line_num, line.rstrip]
          next
        end
      end
    end

    # Pattern 3: Method parameter type: :(id)paramName or :(id *)paramName
    if line_no_comment =~ /:\s*\(\s*\bid\b(?!\s*<)\s*\**\s*\)/
      unless has_inline_comment_exception?(line) || has_comment_on_continuation_lines?(lines, line_num)
        violations << [line_num, line.rstrip]
        next
      end
    end

    # Pattern 4: Instance variable declaration: id _variableName;
    # Be more conservative - only match instance variables (usually start with _)
    if line_no_comment =~ /^\s*\bid\b(?!\s*<)\s+_[a-zA-Z_][a-zA-Z0-9_]*\s*;/
      unless has_inline_comment_exception?(line) || has_comment_on_continuation_lines?(lines, line_num)
        violations << [line_num, line.rstrip]
        next
      end
    end
  end

  violations
end

def main
  options = {
    recursive: false,
    quiet: false,
    color: 'auto',
    exclude: []
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options] files..."
    opts.separator ""
    opts.separator "Checks Objective-C header files for bare 'id' usage without SENTRY_SWIFT_MIGRATION_ID macro."
    opts.separator ""
    opts.separator "Options:"

    opts.on('-r', '--recursive', 'Run recursively over directories') do
      options[:recursive] = true
    end

    opts.on('-q', '--quiet', 'Disable output, useful for the exit code') do
      options[:quiet] = true
    end

    opts.on('--color MODE', ['auto', 'always', 'never'], 'Show colored output (default: auto)') do |mode|
      options[:color] = mode
    end

    opts.on('-e', '--exclude PATTERN', 'Exclude paths matching the given glob-like pattern(s) from recursive search') do |pattern|
      options[:exclude] << pattern
    end

    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit ExitStatus::SUCCESS
    end
  end

  begin
    parser.parse!
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
    warn e.message
    warn parser
    exit ExitStatus::TROUBLE
  end

  if ARGV.empty?
    warn "Error: No files specified"
    warn parser
    exit ExitStatus::TROUBLE
  end

  # Determine color usage
  use_color = case options[:color]
              when 'always' then true
              when 'never' then false
              else $stdout.tty?
              end

  # Only check .h files
  extensions = ['h']

  files = list_files(
    ARGV,
    recursive: options[:recursive],
    exclude: options[:exclude],
    extensions: extensions
  )

  return ExitStatus::SUCCESS if files.empty?

  total_violations = 0

  files.each do |file_path|
    violations = check_id_usage(file_path)

    if violations.any?
      total_violations += violations.length

      unless options[:quiet]
        # Print file header
        error_text = 'Bare id usage found:'
        error_text = bold_red(error_text) if use_color
        puts "\n#{error_text} #{file_path}"

        # Print violations
        violations.each do |line_num, line_content|
          if use_color
            puts "  #{yellow("Line #{line_num}:")} #{line_content}"
          else
            puts "  Line #{line_num}: #{line_content}"
          end
        end
      end
    end
  end

  if total_violations > 0
    unless options[:quiet]
      puts "\n#{'=' * 80}"
      violation_text = "Found #{total_violations} bare 'id' usage(s)"
      violation_text = bold_red(violation_text) if use_color
      puts violation_text
      puts "\nTo fix:"
      puts "1. Use SENTRY_SWIFT_MIGRATION_ID(ClassName) to track temporary workarounds"
      puts "2. Or add inline comment: // OK: explanation why bare id is needed"
      puts "3. Or add inline comment: /* OK: explanation */"
    end
    return ExitStatus::VIOLATIONS_FOUND
  end

  ExitStatus::SUCCESS
end

exit main if __FILE__ == $PROGRAM_NAME
