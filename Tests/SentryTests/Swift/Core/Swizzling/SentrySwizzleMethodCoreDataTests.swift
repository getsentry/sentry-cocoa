#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@testable import Sentry
#endif
import CoreData
import XCTest

final class SentrySwizzleMethodCoreDataTests: XCTestCase {
    func testFetch_whenValidatingCoreData_shouldMatchRuntimeSignature() {
        // -- Arrange --
        let method = SentrySwizzleMethod<NSManagedObjectContext, SentryCoreDataFetchArguments, NSArray?>
            .managedObjectContextFetch(NSManagedObjectContext.self)

        // -- Assert --
        XCTAssertEqual(NSStringFromSelector(method.selector), "executeFetchRequest:error:")
        XCTAssertEqual(method.signature.description, "@@:@^@")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: NSManagedObjectContext.self, method: method))
    }

    func testSave_whenValidatingCoreData_shouldMatchRuntimeSignature() {
        // -- Arrange --
        let method = SentrySwizzleMethod<NSManagedObjectContext, NSErrorPointer, Bool>
            .managedObjectContextSave(NSManagedObjectContext.self)

        // -- Assert --
        XCTAssertEqual(NSStringFromSelector(method.selector), "save:")
        XCTAssertTrue(SentryTypedSwizzle.validate(in: NSManagedObjectContext.self, method: method))
    }

    func testFetch_whenRequestAndErrorArgumentsAreSwapped_shouldRejectSignature() {
        // -- Arrange --
        let method = SentrySwizzleMethod<NSManagedObjectContext, SentryCoreDataFetchArguments, NSArray?>(
            selector: #selector(NSManagedObjectContext.__execute(_:)),
            receiver: NSManagedObjectContext.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .objectPointer, .object])
        )

        // -- Assert --
        XCTAssertFalse(SentryTypedSwizzle.validate(in: NSManagedObjectContext.self, method: method))
    }

    func testSave_whenErrorArgumentIsAnObject_shouldRejectSignature() {
        // -- Arrange --
        let method = SentrySwizzleMethod<NSManagedObjectContext, NSErrorPointer, Bool>(
            selector: #selector(NSManagedObjectContext.save),
            receiver: NSManagedObjectContext.self,
            signature: .init(returnType: .objcBool, arguments: [.object, .selector, .object])
        )

        // -- Assert --
        XCTAssertFalse(SentryTypedSwizzle.validate(in: NSManagedObjectContext.self, method: method))
    }
}
