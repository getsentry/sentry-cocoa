import XCTest

final class MdxOptionsParserTests: XCTestCase {
    
    // MARK: - extractMdxOptionNames Tests
    
    func testExtractMdxOptionNames_whenDoubleQuotes_shouldExtract() {
        let content = """
        <SdkOption name="dsn">
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenSingleQuotes_shouldExtract() {
        let content = """
        <SdkOption name='dsn'>
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenMultipleOptions_shouldExtractAll() {
        let content = """
        <SdkOption name="dsn">
        Some content
        </SdkOption>
        <SdkOption name="enabled">
        More content
        </SdkOption>
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn", "enabled"])
    }
    
    func testExtractMdxOptionNames_whenSpacesAroundEquals_shouldExtract() {
        let content = """
        <SdkOption name = "dsn">
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenEmptyContent_shouldReturnEmpty() {
        let content = ""
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractMdxOptionNames_whenNoSdkOptions_shouldReturnEmpty() {
        let content = """
        # Options Page
        
        This page documents all options.
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractMdxOptionNames_whenHyphenatedName_shouldExtract() {
        let content = """
        <SdkOption name="enable-propagate-trace-parent">
        """
        
        let result = extractMdxOptionNames(from: content)
        
        XCTAssertEqual(result, ["enable-propagate-trace-parent"])
    }
}
