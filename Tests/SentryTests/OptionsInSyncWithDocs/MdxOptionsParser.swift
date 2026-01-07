/// Parses MDX content to extract SdkOption names.
///
/// Matches patterns like `<SdkOption name="optionName">` or `<SdkOption name='optionName'>`.
///
/// - Parameter content: The MDX file content to parse.
/// - Returns: A set of option names found in the content.
@available(iOS 16.0, tvOS 16.0, macOS 13.0, macCatalyst 16.0, *)
func extractMdxOptionNames(from content: String) -> Set<String> {
    // Pattern: <SdkOption name="optionName"> with single or double quotes
    let regex = /<SdkOption\s+name\s*=\s*["'](?<name>[^"']+)["']/
    
    let optionNames = content.matches(of: regex)
        .map { String($0.output.name) }
    
    return Set(optionNames)
}
