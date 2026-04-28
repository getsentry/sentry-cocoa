import Foundation
@_spi(Private) @testable import Sentry
import XCTest

class SentryReplayOptionsNetworkTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }

    func testInit_withInvalidTypes_shouldUseDefaults() {
        // -- Arrange --
        let dict: [String: Any] = [
            "networkDetailAllowUrls": "invalid_string_type", // Should be array
            "networkCaptureBodies": "invalid_string" // Should be boolean
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        XCTAssertEqual(options.networkDetailAllowUrls.count, 0, "networkDetailAllowUrls should fallback to empty array on invalid data provided")
        XCTAssertTrue(options.networkCaptureBodies, "networkCaptureBodies should fallback to true on invalid data provided")
    }
    
    func testNetworkDetailUrls_withEmptyStrings_shouldFilterOutEmptyEntries() {
        // -- Arrange --
        let allowUrls = [
            "https://api.example.com",
            "", // Empty string
            "https://valid.com",
            "   ", // Whitespace only
            "https://another.com"
        ]
        let denyUrls = [
            "https://api.example.com/auth",
            "", // Empty string
            "https://secure.com",
            "   ", // Whitespace only
            "https://private.com"
        ]
        let dict: [String: Any] = [
            "networkDetailAllowUrls": allowUrls,
            "networkDetailDenyUrls": denyUrls
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Both should filter out empty/whitespace entries, leaving 3 valid URLs each
        XCTAssertEqual(options.networkDetailAllowUrls.count, 3)
        XCTAssertEqual(options.networkDetailDenyUrls.count, 3)
        
        // Verify deny URLs contain expected values
        XCTAssertTrue(options.networkDetailDenyUrls.contains(where: { ($0 as? String) == "https://api.example.com/auth" }))
        XCTAssertTrue(options.networkDetailDenyUrls.contains(where: { ($0 as? String) == "https://secure.com" }))
        XCTAssertTrue(options.networkDetailDenyUrls.contains(where: { ($0 as? String) == "https://private.com" }))
    }
    
    // MARK: - Network Details Headers Tests
    
    func testNetworkHeaders_withVariousConfigurations_shouldHandleCorrectly() {
        let expectedDefaultHeaders = ["Content-Type", "Content-Length", "Accept"]
        
        // Test 1: Default configuration (empty dict)
        let defaultOptions = SentryReplayOptions(dictionary: [:])
        XCTAssertEqual(defaultOptions.networkRequestHeaders, expectedDefaultHeaders)
        XCTAssertEqual(defaultOptions.networkResponseHeaders, expectedDefaultHeaders)
        
        // Test 2: Empty arrays should return defaults
        let emptyOptions = SentryReplayOptions(dictionary: [
            "networkRequestHeaders": [],
            "networkResponseHeaders": []
        ])
        XCTAssertEqual(emptyOptions.networkRequestHeaders, expectedDefaultHeaders)
        XCTAssertEqual(emptyOptions.networkResponseHeaders, expectedDefaultHeaders)
        
        // Test 3: Custom headers should be merged with defaults
        let customRequestHeaders = ["Authorization", "User-Agent", "X-Custom-Header", "Accept-Language"]
        let customResponseHeaders = ["Cache-Control", "Set-Cookie", "X-Rate-Limit-Remaining", "Server"]
        let expectedMergedRequestHeaders = ["Content-Type", "Content-Length", "Accept", "Authorization", "User-Agent", "X-Custom-Header", "Accept-Language"]
        let expectedMergedResponseHeaders = ["Content-Type", "Content-Length", "Accept", "Cache-Control", "Set-Cookie", "X-Rate-Limit-Remaining", "Server"]
        let customOptions = SentryReplayOptions(dictionary: [
            "networkRequestHeaders": customRequestHeaders,
            "networkResponseHeaders": customResponseHeaders
        ])
        XCTAssertEqual(customOptions.networkRequestHeaders, expectedMergedRequestHeaders)
        XCTAssertEqual(customOptions.networkResponseHeaders, expectedMergedResponseHeaders)
    }
    
    func testNetworkHeaders_withVariousCases_shouldDeduplicateCaseInsensitively() {
        // -- Arrange --
        let requestHeaders = [
            "content-type", // lowercase - will be skipped due to default "Content-Type"
            "Content-Type", // regular case - will be skipped due to default "Content-Type"  
            "CONTENT-LENGTH", // uppercase - will be skipped due to default "Content-Length"
            "Accept-Encoding", // mixed case - new header
            "x-api-key", // lowercase custom - first occurrence, will be kept
            "X-API-Key" // uppercase custom - duplicate, will be skipped
        ]
        let responseHeaders = [
            "server", // lowercase - new header, will be kept
            "Server", // proper case - duplicate, will be skipped
            "CACHE-CONTROL", // uppercase - new header, will be kept
            "Set-Cookie", // mixed case - new header, will be kept
            "x-rate-limit", // lowercase custom - new header, will be kept
            "X-RATE-LIMIT" // uppercase custom - duplicate, will be skipped
        ]
        let dict: [String: Any] = [
            "networkRequestHeaders": requestHeaders,
            "networkResponseHeaders": responseHeaders
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Request headers: defaults + deduplicated user headers (case preserved from first occurrence)
        // Expected: "Content-Type", "Content-Length", "Accept" (defaults), "Accept-Encoding", "x-api-key"
        let expectedRequestCount = 5
        XCTAssertEqual(options.networkRequestHeaders.count, expectedRequestCount, 
                      "Request headers should be deduplicated, got: \(options.networkRequestHeaders)")
        
        // Check that each header appears exactly once (case-insensitive check)
        let expectedRequestHeadersLowercase = ["content-type", "content-length", "accept", "accept-encoding", "x-api-key"]
        for expectedHeader in expectedRequestHeadersLowercase {
            let matchingHeaders = options.networkRequestHeaders.filter { 
                $0.lowercased() == expectedHeader
            }
            XCTAssertEqual(matchingHeaders.count, 1, 
                          "Header '\(expectedHeader)' should appear exactly once, but found: \(matchingHeaders)")
        }
        
        // Response headers: defaults + deduplicated user headers (case preserved from first occurrence)
        // Expected: "Content-Type", "Content-Length", "Accept" (defaults), "server", "CACHE-CONTROL", "Set-Cookie", "x-rate-limit"
        let expectedResponseCount = 7
        XCTAssertEqual(options.networkResponseHeaders.count, expectedResponseCount,
                      "Response headers should be deduplicated, got: \(options.networkResponseHeaders)")
        
        // Check that each header appears exactly once (case-insensitive check)
        let expectedResponseHeadersLowercase = ["content-type", "content-length", "accept", "server", "cache-control", "set-cookie", "x-rate-limit"]
        for expectedHeader in expectedResponseHeadersLowercase {
            let matchingHeaders = options.networkResponseHeaders.filter { 
                $0.lowercased() == expectedHeader
            }
            XCTAssertEqual(matchingHeaders.count, 1, 
                          "Header '\(expectedHeader)' should appear exactly once, but found: \(matchingHeaders)")
        }
    }
    
    // MARK: - Invalid networkDetailUrls Removal Tests
    
    func testNetworkDetailUrls_withInvalidTypes_shouldFilterOutInvalidEntries() throws {
        // -- Arrange --
        let allowRegex = try NSRegularExpression(pattern: "^https://api\\.example\\.com/.*")
        let denyRegex = try NSRegularExpression(pattern: ".*/private/.*")
        
        let allowUrls: [Any] = [
            "https://api.example.com", // Valid String
            allowRegex, // Valid NSRegularExpression
            123, // Invalid: number
            NSObject(), // Invalid: object
            "https://valid.com", // Valid String
            Date(), // Invalid: Date object
            nil as Any? as Any, // Invalid: nil
            ["nested", "array"] // Invalid: nested array
        ]
        let denyUrls: [Any] = [
            "https://api.example.com/auth", // Valid String
            denyRegex, // Valid NSRegularExpression
            42.5, // Invalid: float number
            nil as Any? as Any, // Invalid: nil
            ["nested", "array"], // Invalid: nested array
            "https://secure.com", // Valid String
            Set<String>(["invalid", "set"]) // Invalid: set object
        ]
        let dict: [String: Any] = [
            "networkDetailAllowUrls": allowUrls,
            "networkDetailDenyUrls": denyUrls
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Both should filter out invalid types, leaving only valid String and NSRegularExpression entries
        XCTAssertEqual(options.networkDetailAllowUrls.count, 3, "Should have 2 Strings and 1 NSRegularExpression")
        XCTAssertEqual(options.networkDetailDenyUrls.count, 3, "Should have 2 Strings and 1 NSRegularExpression")
        
        // Verify allow URLs contain both String and NSRegularExpression types
        var stringCount = 0
        var regexCount = 0
        for entry in options.networkDetailAllowUrls {
            if entry is String {
                stringCount += 1
            } else if entry is NSRegularExpression {
                regexCount += 1
            } else {
                XCTFail("Unexpected type found in allowUrls: \(type(of: entry))")
            }
        }
        XCTAssertEqual(stringCount, 2, "Should have exactly 2 String entries in allowUrls")
        XCTAssertEqual(regexCount, 1, "Should have exactly 1 NSRegularExpression entry in allowUrls")
        
        // Verify deny URLs contain both String and NSRegularExpression types
        stringCount = 0
        regexCount = 0
        for entry in options.networkDetailDenyUrls {
            if entry is String {
                stringCount += 1
            } else if entry is NSRegularExpression {
                regexCount += 1
            } else {
                XCTFail("Unexpected type found in denyUrls: \(type(of: entry))")
            }
        }
        XCTAssertEqual(stringCount, 2, "Should have exactly 2 String entries in denyUrls")
        XCTAssertEqual(regexCount, 1, "Should have exactly 1 NSRegularExpression entry in denyUrls")
        
        // Verify specific String entries are preserved
        let stringAllowUrls = options.networkDetailAllowUrls.compactMap { $0 as? String }
        XCTAssertTrue(stringAllowUrls.contains("https://api.example.com"), "Should preserve first String entry")
        XCTAssertTrue(stringAllowUrls.contains("https://valid.com"), "Should preserve second String entry")
        
        let stringDenyUrls = options.networkDetailDenyUrls.compactMap { $0 as? String }
        XCTAssertTrue(stringDenyUrls.contains("https://api.example.com/auth"), "Should preserve first String entry")
        XCTAssertTrue(stringDenyUrls.contains("https://secure.com"), "Should preserve second String entry")
        
        // Verify NSRegularExpression entries are preserved
        let regexAllowUrls = options.networkDetailAllowUrls.compactMap { $0 as? NSRegularExpression }
        XCTAssertEqual(regexAllowUrls.count, 1, "Should have one NSRegularExpression in allowUrls")
        XCTAssertEqual(regexAllowUrls[0].pattern, allowRegex.pattern, "Should preserve original regex pattern")
        
        let regexDenyUrls = options.networkDetailDenyUrls.compactMap { $0 as? NSRegularExpression }
        XCTAssertEqual(regexDenyUrls.count, 1, "Should have one NSRegularExpression in denyUrls")
        XCTAssertEqual(regexDenyUrls[0].pattern, denyRegex.pattern, "Should preserve original regex pattern")
    }
    
    func testNetworkDetailUrls_withLeadingAndTrailingWhitespace_shouldTrimAndMatch() {
        // -- Arrange --
        let dict: [String: Any] = [
            "networkDetailAllowUrls": [
                "  api.example.com  ",  // Leading and trailing spaces
                "\t\ndata.example.com\n\t",  // Tabs and newlines
                "   ",  // Only whitespace - should be filtered out
                "\n\t",  // Only whitespace - should be filtered out
                "valid.example.com"  // No whitespace
            ],
            "networkDetailDenyUrls": [
                " sensitive.example.com ",
                "\nauth.example.com\t"
            ]
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Verify whitespace-only strings are filtered out
        XCTAssertEqual(options.networkDetailAllowUrls.count, 3, "Should have 3 valid patterns after filtering empty/whitespace strings")
        XCTAssertEqual(options.networkDetailDenyUrls.count, 2, "Should have 2 valid patterns in deny list")
        
        // Verify trimmed strings are stored
        let allowStrings = options.networkDetailAllowUrls.compactMap { $0 as? String }
        XCTAssertEqual(allowStrings.count, 3)
        XCTAssertTrue(allowStrings.contains("api.example.com"), "Should contain trimmed 'api.example.com'")
        XCTAssertTrue(allowStrings.contains("data.example.com"), "Should contain trimmed 'data.example.com'")
        XCTAssertTrue(allowStrings.contains("valid.example.com"), "Should contain 'valid.example.com'")
        
        let denyStrings = options.networkDetailDenyUrls.compactMap { $0 as? String }
        XCTAssertEqual(denyStrings.count, 2)
        XCTAssertTrue(denyStrings.contains("sensitive.example.com"), "Should contain trimmed 'sensitive.example.com'")
        XCTAssertTrue(denyStrings.contains("auth.example.com"), "Should contain trimmed 'auth.example.com'")
        
        // Verify no strings with whitespace are stored
        for string in allowStrings + denyStrings {
            XCTAssertEqual(string, string.trimmingCharacters(in: .whitespacesAndNewlines), 
                          "String '\(string)' should not have leading/trailing whitespace")
        }
        
        // Verify pattern matching works with trimmed strings
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/users"), 
                     "Should match URL containing trimmed pattern 'api.example.com'")
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://data.example.com/analytics"), 
                     "Should match URL containing trimmed pattern 'data.example.com'")
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://sensitive.example.com/data"), 
                      "Should deny URL containing trimmed pattern 'sensitive.example.com'")
    }
    
    // MARK: - Testing isNetworkDetailCaptureEnabled (networkDetailAllowUrls | networkDetailDenyUrls)
    
    func testNetworkDetailUrls_withMixedStringAndRegexTypes_shouldMatchCorrectly() throws {
        // -- Arrange --
        let allowRegex = try NSRegularExpression(pattern: "^https://secure\\.api\\.com/v[0-9]+/.*")
        let denyRegex = try NSRegularExpression(pattern: ".*\\?secret_key=.*")
        let dict: [String: Any] = [
            "networkDetailAllowUrls": [
                "https://data.example.com", // String pattern (substring match)
                allowRegex, // NSRegularExpression pattern - only matches secure.api.com with version
                "/graphql" // Another string pattern
            ],
            "networkDetailDenyUrls": [
                "/internal/", // String pattern (substring match)
                denyRegex // NSRegularExpression pattern - blocks URLs with secret_key param
            ]
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        XCTAssertEqual(options.networkDetailAllowUrls.count, 3)
        XCTAssertEqual(options.networkDetailDenyUrls.count, 2)
        
        // substring pattern matching
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://data.example.com/api/users"),
                     "Should match string pattern 'https://data.example.com'")
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://api.myapp.com/graphql"), 
                     "Should match string pattern '/graphql'")
        
        // regex pattern matching
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://secure.api.com/v2/users"), 
                     "Should match regex pattern for versioned API")
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://secure.api.com/users"), 
                      "Should NOT match regex - missing version number")
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://api.com/v2/users"), 
                      "Should NOT match regex - wrong domain")
        
        // Test deny patterns
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://data.example.com/internal/config"), 
                      "Should be denied by string pattern '/internal/'")
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://secure.api.com/v2/users?secret_key=abc123"), 
                      "Should be denied by regex pattern for secret_key")
        
        // URLs that don't match any allow pattern
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://other.site.com/api"), 
                      "Should not match any allow pattern")
    }
    
    func testIsNetworkDetailCaptureEnabled_withBasicAllowDenyLogic_shouldReturnCorrectResults() {
        // -- Arrange --
        let dict: [String: Any] = [
            "networkDetailAllowUrls": ["api.example.com", "/public/"],
            "networkDetailDenyUrls": ["api.example.com/auth", "/private/"]
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Should allow URLs matching allow patterns but not deny patterns
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/users"))
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://example.com/public/data"))
        
        // Should deny URLs matching deny patterns (deny takes precedence)
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/auth/login"))
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://example.com/private/data"))
        
        // Should deny URLs not matching any allow patterns
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://other.example.com/data"))
    }
    
    func testIsNetworkDetailCaptureEnabled_withRegexPatterns_shouldMatchCorrectly() throws {
        // -- Arrange --
        let allowRegex = try NSRegularExpression(pattern: "^https://api\\.example\\.com/v[0-9]+/.*")
        let denyRegex = try NSRegularExpression(pattern: ".*/(admin|secret)/.*")
        let dict: [String: Any] = [
            "networkDetailAllowUrls": [allowRegex],
            "networkDetailDenyUrls": [denyRegex]
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Should allow URLs matching allow regex
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/v1/users"))
        XCTAssertTrue(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/v2/data"))
        
        // Should deny URLs matching deny regex (even if they match allow)
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/v1/admin/users"))
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/v2/secret/data"))
        
        // Should deny URLs not matching allow regex
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://api.example.com/users")) // Missing version
        XCTAssertFalse(options.isNetworkDetailCaptureEnabled(for: "https://other.example.com/v1/users"))
    }
    
    // MARK: - Header Configuration Tests
    
    func testNetworkHeaders_withCustomHeaders_shouldAlwaysIncludeDefaultHeaders() {
        // -- Arrange --
        let customRequestHeaders = ["Authorization", "X-API-Key"]
        let customResponseHeaders = ["Cache-Control", "X-Rate-Limit"]
        let dict: [String: Any] = [
            "networkRequestHeaders": customRequestHeaders,
            "networkResponseHeaders": customResponseHeaders
        ]
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        let expectedDefaults = ["Content-Type", "Content-Length", "Accept"]
        
        // Request headers should include both defaults and custom headers
        for defaultHeader in expectedDefaults {
            XCTAssertTrue(options.networkRequestHeaders.contains(defaultHeader), 
                         "Default header '\(defaultHeader)' should always be included in request headers")
        }
        for customHeader in customRequestHeaders {
            XCTAssertTrue(options.networkRequestHeaders.contains(customHeader), 
                         "Custom header '\(customHeader)' should be included in request headers")
        }
        
        // Response headers should include both defaults and custom headers
        for defaultHeader in expectedDefaults {
            XCTAssertTrue(options.networkResponseHeaders.contains(defaultHeader), 
                         "Default header '\(defaultHeader)' should always be included in response headers")
        }
        for customHeader in customResponseHeaders {
            XCTAssertTrue(options.networkResponseHeaders.contains(customHeader), 
                         "Custom header '\(customHeader)' should be included in response headers")
        }
    }
    
    func testNetworkHeaders_withCaseInsensitiveDuplicates_shouldPreventDuplicateHeaders() {
        // -- Arrange --
        let headersWithDuplicates = [
            "Content-Type", // Duplicate of default (exact case)
            "content-length", // Duplicate of default (different case)
            "ACCEPT", // Duplicate of default (different case)
            "Authorization", // New header
            "authorization" // Duplicate of above (different case)
        ]
        let dict: [String: Any] = [
            "networkRequestHeaders": headersWithDuplicates
        ]   
        
        // -- Act --
        let options = SentryReplayOptions(dictionary: dict)
        
        // -- Assert --
        // Should have only unique headers (case-insensitive)
        let expectedHeaders = ["Content-Type", "Content-Length", "Accept", "Authorization"]
        XCTAssertEqual(options.networkRequestHeaders.count, expectedHeaders.count)
        
        // Verify each expected header appears exactly once (case-insensitive check)
        for expectedHeader in expectedHeaders {
            let matchingHeaders = options.networkRequestHeaders.filter { 
                $0.lowercased() == expectedHeader.lowercased() 
            }
            XCTAssertEqual(matchingHeaders.count, 1, 
                          "Header '\(expectedHeader)' should appear exactly once, but found: \(matchingHeaders)")
        }
    }
}
