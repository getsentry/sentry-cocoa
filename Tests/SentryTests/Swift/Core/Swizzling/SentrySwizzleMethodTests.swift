@testable import Sentry
import XCTest

final class SentrySwizzleMethodTests: XCTestCase {

    private typealias Method = SentrySwizzleMethod<SwizzleMethodTestTarget, Void, Void>
    private typealias ABIType = Method.ABIType
    private typealias Signature = Method.Signature

    func testInit_shouldStoreReceiverAndSignature() {
        // -- Arrange --
        let selector = #selector(SwizzleMethodTestTarget.invoke)
        let signature = Signature(returnType: .object, arguments: [.object, .selector])

        // -- Act --
        let method = Method(selector: selector, receiver: SwizzleMethodTestTarget.self, signature: signature)

        // -- Assert --
        XCTAssertEqual(method.selector, selector)
        XCTAssertTrue(method.receiver == SwizzleMethodTestTarget.self)
        XCTAssertEqual(method.signature.description, "@@:")
    }

    func testNoArgumentVoid_shouldDescribeObjectiveCInstanceMethodSignature() {
        // -- Act --
        let selector = #selector(SwizzleMethodTestTarget.invoke)
        let method = Method.noArgumentVoid(selector, receiver: SwizzleMethodTestTarget.self)

        // -- Assert --
        XCTAssertEqual(method.selector, selector)
        XCTAssertTrue(method.receiver == SwizzleMethodTestTarget.self)
        XCTAssertEqual(method.signature.description, "v@:")
    }

    func testSignatureDescription_shouldIncludeReturnTypeAndArgumentsInOrder() {
        // -- Arrange --
        let signature = Signature(
            returnType: .object,
            arguments: [.object, .selector, .block, .signedInteger(8)]
        )

        // -- Act --
        let description = signature.description

        // -- Assert --
        XCTAssertEqual(description, "@@:@?signed-int64")
    }

    func testSignatureMatches_whenSignaturesAreEqual_shouldReturnTrue() {
        // -- Arrange --
        let expected = Signature(returnType: .void, arguments: [.object, .selector, .block])
        let actual = Signature(returnType: .void, arguments: [.object, .selector, .block])

        // -- Act --
        let result = expected.matches(actual)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testSignatureMatches_whenReturnTypeDiffers_shouldReturnFalse() {
        // -- Arrange --
        let expected = Signature(returnType: .void, arguments: [.object, .selector])
        let actual = Signature(returnType: .object, arguments: [.object, .selector])

        // -- Act --
        let result = expected.matches(actual)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testSignatureMatches_whenArgumentCountDiffers_shouldReturnFalse() {
        // -- Arrange --
        let expected = Signature(returnType: .void, arguments: [.object, .selector])
        let actual = Signature(returnType: .void, arguments: [.object, .selector, .object])

        // -- Act --
        let result = expected.matches(actual)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testSignatureMatches_whenArgumentTypeDiffers_shouldReturnFalse() {
        // -- Arrange --
        let expected = Signature(returnType: .void, arguments: [.object, .selector, .block])
        let actual = Signature(returnType: .void, arguments: [.object, .selector, .object])

        // -- Act --
        let result = expected.matches(actual)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testABITypeInit_whenEncodingIsFixedType_shouldParseType() {
        // -- Act --
        let void = ABIType(encoding: "v")
        let object = ABIType(encoding: "@")
        let selector = ABIType(encoding: ":")
        let block = ABIType(encoding: "@?")

        // -- Assert --
        XCTAssertEqual(void.description, "v")
        XCTAssertEqual(object.description, "@")
        XCTAssertEqual(selector.description, ":")
        XCTAssertEqual(block.description, "@?")
    }

    func testABITypeInit_whenEncodingIsSignedInteger_shouldParsePlatformSize() {
        // -- Act --
        let character = ABIType(encoding: "c")
        let short = ABIType(encoding: "s")
        let integer = ABIType(encoding: "i")
        let long = ABIType(encoding: "l")
        let longLong = ABIType(encoding: "q")

        // -- Assert --
        XCTAssertEqual(character.description, "signed-int\(MemoryLayout<CChar>.size * 8)")
        XCTAssertEqual(short.description, "signed-int\(MemoryLayout<CShort>.size * 8)")
        XCTAssertEqual(integer.description, "signed-int\(MemoryLayout<CInt>.size * 8)")
        XCTAssertEqual(long.description, "signed-int\(MemoryLayout<CLong>.size * 8)")
        XCTAssertEqual(longLong.description, "signed-int\(MemoryLayout<CLongLong>.size * 8)")
    }

    func testABITypeInit_whenEncodingHasQualifiers_shouldIgnoreQualifiers() {
        // -- Act --
        let constType = ABIType(encoding: "r@")
        let inType = ABIType(encoding: "n@")
        let inoutType = ABIType(encoding: "N@")
        let outType = ABIType(encoding: "o@")
        let bycopyType = ABIType(encoding: "O@")
        let byrefType = ABIType(encoding: "R@")
        let onewayType = ABIType(encoding: "V@")
        let combinedType = ABIType(encoding: "rnNoORV@")

        // -- Assert --
        XCTAssertEqual(constType.description, "@")
        XCTAssertEqual(inType.description, "@")
        XCTAssertEqual(inoutType.description, "@")
        XCTAssertEqual(outType.description, "@")
        XCTAssertEqual(bycopyType.description, "@")
        XCTAssertEqual(byrefType.description, "@")
        XCTAssertEqual(onewayType.description, "@")
        XCTAssertEqual(combinedType.description, "@")
    }

    func testABITypeInit_whenEncodingIsEmpty_shouldReturnUnsupported() {
        // -- Act --
        let type = ABIType(encoding: "")

        // -- Assert --
        XCTAssertEqual(type.description, "?")
    }

    func testABITypeInit_whenEncodingIsNotSupported_shouldReturnUnsupported() {
        // -- Act --
        let unsignedInteger = ABIType(encoding: "I")
        let float = ABIType(encoding: "f")
        let pointer = ABIType(encoding: "^v")
        let structure = ABIType(encoding: "{Point=dd}")

        // -- Assert --
        XCTAssertEqual(unsignedInteger.description, "?")
        XCTAssertEqual(float.description, "?")
        XCTAssertEqual(pointer.description, "?")
        XCTAssertEqual(structure.description, "?")
    }

    func testABITypeMatches_whenFixedTypesAreEqual_shouldReturnTrue() {
        // -- Assert --
        XCTAssertTrue(ABIType.void.matches(.void))
        XCTAssertTrue(ABIType.object.matches(.object))
        XCTAssertTrue(ABIType.selector.matches(.selector))
        XCTAssertTrue(ABIType.block.matches(.block))
    }

    func testABITypeMatches_whenFixedTypesDiffer_shouldReturnFalse() {
        // -- Assert --
        XCTAssertFalse(ABIType.void.matches(.object))
        XCTAssertFalse(ABIType.object.matches(.block))
        XCTAssertFalse(ABIType.selector.matches(.object))
        XCTAssertFalse(ABIType.block.matches(.object))
    }

    func testABITypeMatches_whenSignedIntegerSizesAreEqual_shouldReturnTrue() {
        // -- Act --
        let result = ABIType.signedInteger(8).matches(.signedInteger(8))

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testABITypeMatches_whenSignedIntegerSizesDiffer_shouldReturnFalse() {
        // -- Act --
        let result = ABIType.signedInteger(4).matches(.signedInteger(8))

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testABITypeMatches_whenTypeIsUnsupported_shouldReturnFalse() {
        // -- Assert --
        XCTAssertFalse(ABIType.unsupported.matches(.unsupported))
        XCTAssertFalse(ABIType.unsupported.matches(.object))
        XCTAssertFalse(ABIType.object.matches(.unsupported))
    }
}

private final class SwizzleMethodTestTarget: NSObject {
    @objc dynamic func invoke() {}
}
