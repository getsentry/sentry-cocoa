import Foundation

/// Parses MDX documentation files to extract SdkOption names.
/// Used by SentryOptionsDocumentationSyncTests to validate documentation coverage.
struct MdxOptionsParser {
    
    /// Parses MDX content to extract SdkOption names.
    ///
    /// Matches patterns like `<SdkOption name="optionName">` or `<SdkOption name='optionName'>`.
    ///
    /// - Parameter content: The MDX file content to parse.
    /// - Returns: A set of option names found in the content.
    func extractOptionNames(from content: String) -> Set<String> {
        var options = Set<String>()
        
        // Pattern: <SdkOption name="optionName"
        // We need to handle both single and double quotes
        let pattern = #"<SdkOption\s+name\s*=\s*[\"']([^\"']+)[\"']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return options
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: content) {
                let optionName = String(content[nameRange])
                options.insert(optionName)
            }
        }
        
        return options
    }
}
