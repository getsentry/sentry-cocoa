import XCTest

@available(iOS 16.0, tvOS 16.0, macOS 13.0, macCatalyst 16.0, *)
final class MdxOptionsParserTests: XCTestCase {
    
    func testExtractMdxOptionNames_whenDoubleQuotes_shouldExtract() {
        // Arrange
        let content = """
        <SdkOption name="dsn">
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenSingleQuotes_shouldExtract() {
        // Arrange
        let content = """
        <SdkOption name='dsn'>
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenMultipleOptions_shouldExtractAll() {
        // Arrange
        let content = """
        <SdkOption name="dsn">
        Some content
        </SdkOption>
        <SdkOption name="enabled">
        More content
        </SdkOption>
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertEqual(result, ["dsn", "enabled"])
    }
    
    func testExtractMdxOptionNames_whenSpacesAroundEquals_shouldExtract() {
        // Arrange
        let content = """
        <SdkOption name = "dsn">
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertEqual(result, ["dsn"])
    }
    
    func testExtractMdxOptionNames_whenEmptyContent_shouldReturnEmpty() {
        // Arrange
        let content = ""
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractMdxOptionNames_whenNoSdkOptions_shouldReturnEmpty() {
        // Arrange
        let content = """
        # Options Page
        
        This page documents all options.
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)
        
        // Assert
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractMdxOptionNames_whenHyphenatedName_shouldExtract() {
        // Arrange
        let content = """
        <SdkOption name="enable-propagate-trace-parent">
        """
        
        // Act
        let result = extractMdxOptionNames(from: content)

        // Assert
        XCTAssertEqual(result, ["enable-propagate-trace-parent"])
    }
}
