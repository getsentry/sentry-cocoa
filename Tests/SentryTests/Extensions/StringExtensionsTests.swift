import Foundation
@testable import Sentry
import XCTest

class StringExtensionsTests: XCTestCase {

    // MARK: - Happy path

    func testSnakeToCamelCase_whenMultipleUnderscores_shouldCamelCaseEachWord() {
        // -- Arrange --
        let input = "name_something_else"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        XCTAssertEqual(result, "nameSomethingElse")
    }

    func testSnakeToCamelCase_whenNoUnderscore_shouldReturnUnchanged() {
        // -- Arrange --
        let input = "plain"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        XCTAssertEqual(result, "plain")
    }

    func testSnakeToCamelCase_whenAlreadyUppercase_shouldPreserveExistingCase() {
        // -- Arrange --
        let input = "KEEP_CASE"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        XCTAssertEqual(result, "KEEPCASE")
    }

    // MARK: - Edge cases

    func testSnakeToCamelCase_whenEmpty_shouldReturnEmpty() {
        // -- Arrange --
        let input = ""

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        XCTAssertEqual(result, "")
    }

    func testSnakeToCamelCase_whenLeadingUnderscore_shouldCapitalizeFirstLetter() {
        // -- Arrange --
        let input = "_name"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        // A leading underscore flips the very first character to uppercase.
        XCTAssertEqual(result, "Name")
    }

    func testSnakeToCamelCase_whenTrailingUnderscore_shouldDropIt() {
        // -- Arrange --
        let input = "name_"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        // A trailing underscore has no following character, so it is dropped.
        XCTAssertEqual(result, "name")
    }

    func testSnakeToCamelCase_whenConsecutiveUnderscores_shouldCollapseToSingleCamelHump() {
        // -- Arrange --
        let input = "name__something"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        XCTAssertEqual(result, "nameSomething")
    }

    // MARK: - Non-letter & non-ASCII characters

    func testSnakeToCamelCase_whenContainsSymbolsAndDigits_shouldKeepThemUnchanged() {
        // -- Arrange --
        let input = "set_50%_done!"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        // Non-letters (digits, '%', '!') "uppercase" to themselves and pass through untouched.
        XCTAssertEqual(result, "set50%Done!")
    }

    func testSnakeToCamelCase_whenContainsFrenchAccents_shouldPreserveAndUppercaseThem() {
        // -- Arrange --
        let input = "crème_brûlée_élevé"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        // Accents within a word stay; 'é' right after an underscore becomes 'É'.
        XCTAssertEqual(result, "crèmeBrûléeÉlevé")
    }

    func testSnakeToCamelCase_whenContainsGermanEszett_shouldExpandToDoubleSAfterUnderscore() {
        // -- Arrange --
        let input = "über_ßee"

        // -- Act --
        let result = input.snakeToCamelCase()

        // -- Assert --
        // 'ß' uppercases to "SS", so a single character after an underscore expands to two.
        XCTAssertEqual(result, "überSSee")
    }
}
