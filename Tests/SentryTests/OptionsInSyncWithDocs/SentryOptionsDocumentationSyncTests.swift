import XCTest

/// This test validates that all public properties in Options.swift have corresponding
/// documentation entries in the sentry-docs repository.
///
/// Docs source: https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx
///
/// If this test fails, either:
/// 1. Add documentation for the new option in sentry-docs
/// 2. Add the option to `undocumentedOptions` (for options pending documentation)
final class SentryOptionsDocumentationSyncTests: XCTestCase {
    
    private let propertyExtractor = ObjcPropertyExtractor()
    private let mdxParser = MdxOptionsParser()
    
    // MARK: - Ignore Lists
    
    /// Platform-specific options that are only available on certain platforms.
    /// These are excluded from validation since they may not be visible at runtime
    /// depending on which platform the tests run on.
    private let platformSpecificOptions: Set<String> = [
        // macOS only (#if os(macOS))
        "enableUncaughtNSExceptionReporting"
    ]
    
    /// Options not yet documented in the common options page.
    /// We plan to add documentation for all of these soon.
    /// Remove options from this list as they get documented.
    private let undocumentedOptions: Set<String> = [
        // Internal/derived properties (including @_spi(Private))
        "parsedDsn",
        "isTracingEnabled",
        "profiling", // @_spi(Private) - internal backing for configureProfiling
        "userFeedbackConfiguration", // @_spi(Private) - internal backing for configureUserFeedback
        
        // SDK behavior
        "enabled",
        "shutdownTimeInterval",
        
        // Crash handling
        "enableCrashHandler",
        "enableWatchdogTerminationTracking",
        
        // Session tracking
        "sessionTrackingIntervalMillis",
        
        // Attachments
        "maxAttachmentSize",
        "screenshot",
        "reportAccessibilityIdentifier",
        
        // Performance tracing
        "enableAutoPerformanceTracing",
        "enableUIViewControllerTracing",
        "enableUserInteractionTracing",
        "enablePreWarmedAppStartTracing",
        "enableNetworkTracking",
        "enableFileIOTracing",
        "enableDataSwizzling",
        "enableFileManagerSwizzling",
        "enableCoreDataTracing",
        "enableTimeToFullDisplayTracing",
        
        // App hangs
        "enableAppHangTracking",
        "appHangTimeoutInterval",
        "enableReportNonFullyBlockingAppHangs",
        
        // Swizzling
        "enableSwizzling",
        "swizzleClassNameExcludes",
        
        // URLSession
        "urlSessionDelegate",
        "urlSession",
        
        // Breadcrumbs
        "enableAutoBreadcrumbTracking",
        
        // Failed requests
        "failedRequestStatusCodes",
        "failedRequestTargets",
        
        // MetricKit
        "enableMetricKit",
        "enableMetricKitRawPayload",
        
        // Experimental
        "swiftAsyncStacktraces",
        "experimental",
        
        // Storage
        "cacheDirectoryPath",
        
        // Spotlight
        "enableSpotlight",
        "spotlightUrl",
        
        // Profiling
        "configureProfiling",
        
        // Session replay (documented at https://docs.sentry.io/platforms/apple/session-replay/)
        "sessionReplay",
        
        // User feedback
        "configureUserFeedback",
        
        // Callbacks
        "beforeSendSpan",
        "beforeSendLog",
        "beforeCaptureScreenshot",
        "beforeCaptureViewHierarchy",
        "onCrashedLastRun",
        
        // Logs
        "enableLogs"
    ]
    
    /// Mapping between a code property name and its documentation name when they differ.
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
    
    // MARK: - Constants
    
    private let docsURL = "https://raw.githubusercontent.com/getsentry/sentry-docs/master/docs/platforms/apple/common/configuration/options.mdx"
    
    // MARK: - Tests
    
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    func testAllOptionsAreDocumented() async throws {
        // Extract properties from Options using Mirror reflection
        let codeProperties = extractPropertiesFromOptions()
        
        // Fetch and parse documentation
        let documentedOptions = try await fetchDocumentedOptions()
        
        // Find properties that are not documented and not ignored
        var missingDocs: [String] = []
        
        // Combine all ignored options
        let allIgnoredOptions = undocumentedOptions.union(platformSpecificOptions)
        
        for property in codeProperties {
            // Check if it's in the ignore list
            if allIgnoredOptions.contains(property) {
                continue
            }
            
            // Check direct match
            if documentedOptions.contains(property) {
                continue
            }
            
            // Check mapped name
            if let mapping = optionNameMappings.first(where: { $0.codeName == property }),
               documentedOptions.contains(mapping.docsName) {
                continue
            }
            
            // Not found
            missingDocs.append(property)
        }
        
        // Fail if there are undocumented options
        if !missingDocs.isEmpty {
            let message = """
            
            ❌ The following Options.swift properties are not documented in sentry-docs:
            
            \(missingDocs.map { "   - \($0)" }.joined(separator: "\n"))
            
            To fix this:
            1. Add documentation for these options in sentry-docs:
               https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx
            
            2. OR add them to the ignoredOptions dictionary in this test with a reason:
               - If docs PR is pending, include the PR link
               - If it's an internal property, explain why it shouldn't be documented
            
            """
            XCTFail(message)
        }
    }
    
    func testIgnoredOptionsExistInCode() {
        let codeProperties = extractPropertiesFromOptions()
        
        var invalidOptions: [String] = []
        
        for option in undocumentedOptions {
            // Skip platform-specific options as they may not be visible at runtime
            if platformSpecificOptions.contains(option) {
                continue
            }
            
            if !codeProperties.contains(option) {
                invalidOptions.append(option)
            }
        }
        
        if !invalidOptions.isEmpty {
            let missingList = invalidOptions.sorted().map { "   - \($0)" }.joined(separator: "\n")
            XCTFail("""
            The following options in undocumentedOptions do not exist in Options.swift:
            \(missingList)
            
            Remove them from undocumentedOptions or add them to platformSpecificOptions if they are
            conditionally compiled for specific platforms.
            """)
        }
    }
    
    // MARK: - Helpers
    
    /// Extracts all stored property names from Options using Mirror reflection.
    private func extractPropertiesFromOptions() -> Set<String> {
        return propertyExtractor.extractPropertyNames()
    }
    
    /// Fetches the options.mdx file from GitHub and extracts documented option names
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchDocumentedOptions() async throws -> Set<String> {
        let url = try XCTUnwrap(URL(string: docsURL), "Invalid docs URL")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse, "Response is not HTTPURLResponse")
        XCTAssertEqual(httpResponse.statusCode, 200, "Failed to fetch docs: HTTP \(httpResponse.statusCode)")
        
        let content = try XCTUnwrap(String(data: data, encoding: .utf8), "Could not decode docs content as UTF-8")
        
        return mdxParser.extractOptionNames(from: content)
    }
}
