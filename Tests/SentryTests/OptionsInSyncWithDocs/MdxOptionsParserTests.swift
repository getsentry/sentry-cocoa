import XCTest

final class MdxOptionsParserTests: XCTestCase {
    
    private let sut = MdxOptionsParser()
    
    // MARK: - extractOptionNames Tests
    
    func testExtractOptionNames_whenDoubleQuotes_shouldExtract() {
        let content = """
        <SdkOption name="dsn">
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractOptionNames_whenSingleQuotes_shouldExtract() {
        let content = """
        <SdkOption name='dsn'>
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractOptionNames_whenMultipleOptions_shouldExtractAll() {
        let content = """
        <SdkOption name="dsn">
        Some content
        </SdkOption>
        <SdkOption name="enabled">
        More content
        </SdkOption>
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn", "enabled"])
    }
    
    func testExtractOptionNames_whenSpacesAroundEquals_shouldExtract() {
        let content = """
        <SdkOption name = "dsn">
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractOptionNames_whenEmptyContent_shouldReturnEmpty() {
        let content = ""
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractOptionNames_whenNoSdkOptions_shouldReturnEmpty() {
        let content = """
        # Options Page
        
        This page documents all options.
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractOptionNames_whenHyphenatedName_shouldExtract() {
        let content = """
        <SdkOption name="enable-propagate-trace-parent">
        """
        
        let result = sut.extractOptionNames(from: content)
        
        XCTAssertEqual(result, ["enable-propagate-trace-parent"])
    }
}
