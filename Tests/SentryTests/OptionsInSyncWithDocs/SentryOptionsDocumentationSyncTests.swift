import XCTest

/// This test validates that all public properties in Options.swift have corresponding
/// documentation entries in the sentry-docs repository.
///
/// Docs source: https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx
///
/// If this test fails, either:
/// 1. Add documentation for the new option in sentry-docs
/// 2. Add the option to `undocumentedOptions` (for options pending documentation)
@available(iOS 26.0, tvOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class SentryOptionsDocumentationSyncTests: XCTestCase {
    
    // MARK: - Ignore Lists
    
    /// Options not yet documented in the common options page.
    /// We plan to add documentation for all of these soon.
    /// Remove options from this list as they get documented.
    ///
    /// Note: Platform-specific options are conditionally included using compiler flags
    /// to match the availability in Options.swift.
    private var undocumentedOptions: Set<String> {
        var options: Set<String> = [
            // Internal/derived properties (including @_spi(Private))
            "parsedDsn",
            "isTracingEnabled",
            "profiling", // @_spi(Private) - internal backing for configureProfiling
            
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
            
            // Performance tracing
            "enableAutoPerformanceTracing",
            "enableNetworkTracking",
            "enableFileIOTracing",
            "enableDataSwizzling",
            "enableFileManagerSwizzling",
            "enableCoreDataTracing",
            "enableTimeToFullDisplayTracing",
            
            // App hangs
            "enableAppHangTracking",
            "appHangTimeoutInterval",
            
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
            
            // Callbacks
            "beforeSendSpan",
            "beforeSendLog",
            "beforeCaptureScreenshot",
            "beforeCaptureViewHierarchy",
            "onCrashedLastRun",
            
            // Logs
            "enableLogs"
        ]
        
        // macOS only (#if os(macOS))
        #if os(macOS)
        options.insert("enableUncaughtNSExceptionReporting")
        #endif
        
        // iOS/tvOS/visionOS with UIKit (#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT)
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        options.insert("enableUIViewControllerTracing")
        options.insert("screenshot")
        options.insert("reportAccessibilityIdentifier")
        options.insert("enableUserInteractionTracing")
        options.insert("enablePreWarmedAppStartTracing")
        options.insert("enableReportNonFullyBlockingAppHangs")
        #endif
        
        // iOS/tvOS with UIKit (#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT)
        // Session replay (documented at https://docs.sentry.io/platforms/apple/session-replay/)
        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
        options.insert("sessionReplay")
        #endif
        
        // iOS only with UIKit (#if os(iOS) && !SENTRY_NO_UIKIT)
        #if os(iOS) && !SENTRY_NO_UIKIT
        options.insert("userFeedbackConfiguration") // @_spi(Private) - internal backing for configureUserFeedback
        options.insert("configureUserFeedback")
        #endif
        
        return options
    }
    
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
    
    // MARK: - Tests
    
    func testAllOptionsAreDocumented() async throws {
        // Extract properties from Options using Objective-C runtime and Mirror reflection
        let codeProperties = extractPropertyNames(from: Options())
        
        // Fetch and parse documentation
        let documentedOptions = try await fetchDocumentedOptions()
        
        // Find properties that are not documented and not ignored
        var missingDocs: [String] = []
        
        for property in codeProperties {
            // Check if it's in the undocumented ignore list
            if undocumentedOptions.contains(property) {
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
        let codeProperties = extractPropertyNames(from: Options())
        
        var invalidOptions: [String] = []
        
        for option in undocumentedOptions {
            if !codeProperties.contains(option) {
                invalidOptions.append(option)
            }
        }
        
        if !invalidOptions.isEmpty {
            let missingList = invalidOptions.sorted().map { "   - \($0)" }.joined(separator: "\n")
            XCTFail("""
            The following options in undocumentedOptions do not exist in Options.swift:
            \(missingList)
            
            Either remove them from undocumentedOptions, or if they are platform-specific,
            add them with the appropriate compiler flags (e.g., #if os(iOS)).
            """)
        }
    }
    
    // MARK: - Helpers
    
    /// Fetches the options.mdx file from GitHub and extracts documented option names
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
