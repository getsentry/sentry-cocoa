import XCTest

/// This test validates that all public properties in Options.swift have corresponding
/// documentation entries in the sentry-docs repository.
///
/// Docs source: https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx
@available(iOS 26.0, tvOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class SentryOptionsDocumentationSyncTests: XCTestCase {

    /// Options not yet documented in the common options page.
    /// We plan to add documentation for all of these soon.
    /// Remove options from this list as they get documented.
    ///
    /// Note: Platform-specific options are conditionally included using compiler flags
    /// to match the availability in Options.swift.
    private var undocumentedOptions: Set<String> {
        var options: Set<String> = [
            "parsedDsn",
            "experimental"
        ]
        
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        options.insert("screenshot")
        #endif

        // Session replay (documented at https://docs.sentry.io/platforms/apple/session-replay/)
        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
        options.insert("sessionReplay")
        #endif

        #if os(iOS) && !SENTRY_NO_UIKIT
        options.insert("userFeedbackConfiguration") // @_spi(Private) - internal backing for configureUserFeedback
        options.insert("configureUserFeedback")
        #endif

        #if !(os(tvOS) || os(visionOS))
        options.insert("profiling") // @_spi(Private) - internal backing for configureProfiling
        options.insert("configureProfiling")
        #endif
        
        return options
    }

    private struct OptionNameMapping {
        let codeName: String
        let docsName: String
    }
    
    /// Known mappings where the code property name differs from the documentation option name.
    private let optionNameMappings: [OptionNameMapping] = [
        OptionNameMapping(codeName: "enableAutoSessionTracking", docsName: "autoSessionTracking"),
        OptionNameMapping(codeName: "inAppIncludes", docsName: "inAppInclude"),
        OptionNameMapping(codeName: "enablePropagateTraceparent", docsName: "enable-propagate-trace-parent")
    ]
    
    func testAllOptionsAreDocumentedInSentryDocs() async throws {

        let optionProperties = extractPropertyNames(from: Options())

        let documentedOptions = try await fetchDocumentedOptions()
        
        // Warn about options in undocumentedOptions that are now documented
        let undocumentedOptionsThatAreActuallyDocumented = undocumentedOptions
            .filter { documentedOptions.contains($0) }
            .sorted()
        
        if !undocumentedOptionsThatAreActuallyDocumented.isEmpty {
            print("""
                ⚠️ The following options are now documented and can be removed from undocumentedOptions:
                
                \(undocumentedOptionsThatAreActuallyDocumented.map { "   - \($0)" }.joined(separator: "\n"))
                """)
        }
        
        // Find properties that are not documented and not ignored
        let propertiesMissingDocs = optionProperties
            .filter { !undocumentedOptions.contains($0) }
            .filter { !documentedOptions.contains($0) }
            .filter { property in
                // Check if there's a mapping with a documented name
                guard let mapping = optionNameMappings.first(where: { $0.codeName == property }) else {
                    return true // No mapping exists, property is missing
                }
                return !documentedOptions.contains(mapping.docsName)
            }
            .sorted()
        
        XCTAssertTrue(propertiesMissingDocs.isEmpty, """
            ❌ The following Options.swift properties are not documented in sentry-docs:
            
            \(propertiesMissingDocs.map { "   - \($0)" }.joined(separator: "\n"))
            
            To fix this:
            1. Add documentation for these options in sentry-docs:
               https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx
            
            2. OR add them to the SentryOptionsDocumentationSyncTests.undocumentedOptions with a reason.
            """)
    }
    
    func testIgnoredOptionsExistInCode() {
        let codeProperties = extractPropertyNames(from: Options())
        
        let invalidOptions = undocumentedOptions
            .filter { !codeProperties.contains($0) }
            .sorted()
        
        XCTAssertTrue(invalidOptions.isEmpty, """
            The following options in undocumentedOptions do not exist in Options.swift:
            
            \(invalidOptions.map { "   - \($0)" }.joined(separator: "\n"))
            
            Either remove them from undocumentedOptions, or if they are platform-specific,
            add them with the appropriate compiler flags (e.g., #if os(iOS)).
            """)
    }

    private func fetchDocumentedOptions() async throws -> Set<String> {
        let docsURL = "https://raw.githubusercontent.com/getsentry/sentry-docs/master/docs/platforms/apple/common/configuration/options.mdx"
        let url = try XCTUnwrap(URL(string: docsURL), "Invalid docs URL")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse, "Response is not HTTPURLResponse")
        XCTAssertEqual(httpResponse.statusCode, 200, "Failed to fetch docs: HTTP \(httpResponse.statusCode)")
        
        let content = try XCTUnwrap(String(data: data, encoding: .utf8), "Could not decode docs content as UTF-8")
        
        return extractMdxOptionNames(from: content)
    }
}
