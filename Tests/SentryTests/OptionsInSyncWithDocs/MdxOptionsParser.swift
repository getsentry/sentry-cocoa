import Foundation

/// Parses MDX content to extract SdkOption names.
///
/// Matches patterns like `<SdkOption name="optionName">` or `<SdkOption name='optionName'>`.
///
/// - Parameter content: The MDX file content to parse.
/// - Returns: A set of option names found in the content.
func extractMdxOptionNames(from content: String) -> Set<String> {
    // Pattern: <SdkOption name="optionName"
    // We need to handle both single and double quotes
    let pattern = #"<SdkOption\s+name\s*=\s*[\"']([^\"']+)[\"']"#
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return []
    }
    
    let range = NSRange(content.startIndex..., in: content)
    let optionNames = regex.matches(in: content, options: [], range: range)
        .compactMap { Range($0.range(at: 1), in: content) }
        .map { String(content[$0]) }
    
    return Set(optionNames)
}
