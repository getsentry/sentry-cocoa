#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#else
@testable import Sentry
#endif
import _SentryPrivate
import CoreData
import ObjectiveC
import XCTest

final class SentryTypedSwizzleCoreDataTests: XCTestCase {
    private typealias FetchMethod = SentrySwizzleMethod<CoreDataSwizzleTarget, SentryCoreDataFetchArguments, NSArray?>
    private typealias SaveMethod = SentrySwizzleMethod<CoreDataSwizzleTarget, NSErrorPointer, Bool>
    private var installations: [(selector: Selector, key: SentryTypedSwizzle.Key)] = []

    override func tearDown() {
        for installation in installations.reversed() {
            for target in [CoreDataSwizzleChild.self, CoreDataSwizzleTarget.self] {
                SentrySwizzle.unswizzleInstanceMethod(installation.selector, in: target, key: installation.key.pointer)
            }
        }
        installations.removeAll()
        super.tearDown()
    }

    func testFetch_whenIntercepted_shouldReplaceRequestAndForwardResultAndError() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Original")
        let replacement = NSFetchRequest<NSFetchRequestResult>(entityName: "Replacement")
        target.result = NSArray(object: NSObject())
        target.error = NSError(domain: "CoreDataSwizzleTests", code: 42)
        var error: NSError?
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .always, key: key()) { receiver, receivedRequest, error, original in
            calls += 1
            XCTAssertTrue(receiver === target)
            XCTAssertTrue(receivedRequest === request)
            return original(replacement, error)
        }

        // -- Act --
        let result = target.fetch(request, error: &error)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.fetchCalls, 1)
        XCTAssertTrue(target.request === replacement)
        XCTAssertTrue(result === target.result)
        XCTAssertTrue(error === target.error)
    }

    func testFetch_whenErrorPointerAndResultAreNil_shouldPreserveNil() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        let request = NSFetchRequest<NSFetchRequestResult>()
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .always, key: key()) { _, request, error, original in
            calls += 1
            XCTAssertNil(error)
            return original(request, error)
        }

        // -- Act --
        let result = target.fetch(request, error: nil)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertNil(result)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.fetchCalls, 1)
        XCTAssertTrue(target.errorWasNil)
    }

    func testSave_whenOriginalFails_shouldForwardFalseAndError() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        target.error = NSError(domain: "CoreDataSwizzleTests", code: 42)
        var error: NSError?
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: saveMethod, mode: .always, key: key(saveMethod.selector)) { receiver, error, original in
            calls += 1
            XCTAssertTrue(receiver === target)
            return original(error)
        }

        // -- Act --
        let result = target.save(&error)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertFalse(result)
        XCTAssertTrue(error === target.error)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.saveCalls, 1)
    }

    func testSave_whenOriginalSucceedsWithNilErrorPointer_shouldForwardTrue() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        target.saveResult = true
        var calls = 0
        let installed = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: saveMethod, mode: .always, key: key(saveMethod.selector)) { _, error, original in
            calls += 1
            XCTAssertNil(error)
            return original(error)
        }

        // -- Act --
        let result = target.save(nil)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertTrue(result)
        XCTAssertTrue(target.errorWasNil)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.saveCalls, 1)
    }

    func testSave_whenInterceptorReplacesErrorPointerAndResult_shouldUseReplacements() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        target.error = NSError(domain: "CoreDataSwizzleTests", code: 42)
        var originalError: NSError?
        let installed = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: saveMethod, mode: .always, key: key(saveMethod.selector)) { _, _, original in
            XCTAssertFalse(original(&originalError))
            return true
        }
        var callerError: NSError?

        // -- Act --
        let result = target.save(&callerError)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertTrue(result)
        XCTAssertNil(callerError)
        XCTAssertTrue(originalError === target.error)
        XCTAssertEqual(target.saveCalls, 1)
    }

    func testFetch_whenInstalledTwiceWithSameKey_shouldCallInterceptorOnce() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        let stableKey = key()
        var calls = 0
        let intercept: (CoreDataSwizzleTarget, NSFetchRequest<NSFetchRequestResult>, NSErrorPointer, @escaping (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?) -> NSArray? = { _, request, error, original in
            calls += 1
            return original(request, error)
        }

        // -- Act --
        let first = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .oncePerClassAndSuperclasses, key: stableKey, interceptor: intercept)
        let second = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .oncePerClassAndSuperclasses, key: stableKey, interceptor: intercept)
        _ = target.fetch(NSFetchRequest<NSFetchRequestResult>(), error: nil)

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(target.fetchCalls, 1)
    }

    func testFetch_whenUsingDifferentKeys_shouldChainOriginalImplementations() {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        var order: [String] = []
        let first = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .oncePerClassAndSuperclasses, key: key()) { _, request, error, original in
            order.append("first")
            return original(request, error)
        }
        let second = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetchMethod, mode: .oncePerClassAndSuperclasses, key: key()) { _, request, error, original in
            order.append("second")
            return original(request, error)
        }

        // -- Act --
        _ = target.fetch(NSFetchRequest<NSFetchRequestResult>(), error: nil)

        // -- Assert --
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(order, ["second", "first"])
        XCTAssertEqual(target.fetchCalls, 1)
    }

    func testFetchAndSave_whenReceiverCastFails_shouldStillCallOriginal() throws {
        // -- Arrange --
        let target = CoreDataSwizzleTarget()
        target.saveResult = true
        target.result = NSArray(object: NSObject())
        var calls = 0
        let fetch = SentrySwizzleMethod<CoreDataSwizzleChild, SentryCoreDataFetchArguments, NSArray?>(
            selector: #selector(CoreDataSwizzleTarget.fetch(_:error:)), receiver: CoreDataSwizzleChild.self,
            signature: .init(returnType: .object, arguments: [.object, .selector, .object, .objectPointer])
        )
        let save = SentrySwizzleMethod<CoreDataSwizzleChild, NSErrorPointer, Bool>(
            selector: #selector(CoreDataSwizzleTarget.save(_:)), receiver: CoreDataSwizzleChild.self,
            signature: .init(returnType: .objcBool, arguments: [.object, .selector, .objectPointer])
        )
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleChild.self, method: fetch, mode: .always, key: key()) { _, request, error, original in
            calls += 1
            return original(request, error)
        })
        XCTAssertTrue(SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleChild.self, method: save, mode: .always, key: key(save.selector)) { _, error, original in
            calls += 1
            return original(error)
        })
        let fetchImp = try XCTUnwrap(class_getMethodImplementation(CoreDataSwizzleChild.self, fetch.selector))
        let saveImp = try XCTUnwrap(class_getMethodImplementation(CoreDataSwizzleChild.self, save.selector))
        let callFetch = unsafeBitCast(fetchImp, to: (@convention(c) (AnyObject, Selector, NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?).self)
        let callSave = unsafeBitCast(saveImp, to: (@convention(c) (AnyObject, Selector, NSErrorPointer) -> ObjCBool).self)

        // -- Act --
        let result = callFetch(target, fetch.selector, NSFetchRequest<NSFetchRequestResult>(), nil)
        let saved = callSave(target, save.selector, nil)

        // -- Assert --
        XCTAssertTrue(result === target.result)
        XCTAssertTrue(saved.boolValue)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(target.fetchCalls, 1)
        XCTAssertEqual(target.saveCalls, 1)
    }

    func testFetchAndSave_whenValidationFails_shouldNotInstall() {
        // -- Arrange --
        let fetch = FetchMethod(selector: fetchMethod.selector, receiver: CoreDataSwizzleTarget.self,
                                signature: .init(returnType: .void, arguments: [.object, .selector, .object, .objectPointer]))
        let save = SaveMethod(selector: saveMethod.selector, receiver: CoreDataSwizzleTarget.self,
                              signature: .init(returnType: .object, arguments: [.object, .selector, .objectPointer]))

        // -- Act --
        let fetchInstalled = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: fetch, mode: .always, key: key()) { _, request, error, original in
            XCTFail("Invalid fetch interceptor should not run")
            return original(request, error)
        }
        let saveInstalled = SentryTypedSwizzle.instanceMethod(in: CoreDataSwizzleTarget.self, method: save, mode: .always, key: key(save.selector)) { _, error, original in
            XCTFail("Invalid save interceptor should not run")
            return original(error)
        }

        // -- Assert --
        XCTAssertFalse(fetchInstalled)
        XCTAssertFalse(saveInstalled)
    }

    private var fetchMethod: FetchMethod {
        .init(selector: #selector(CoreDataSwizzleTarget.fetch(_:error:)), receiver: CoreDataSwizzleTarget.self,
              signature: .init(returnType: .object, arguments: [.object, .selector, .object, .objectPointer]))
    }

    private var saveMethod: SaveMethod {
        .init(selector: #selector(CoreDataSwizzleTarget.save(_:)), receiver: CoreDataSwizzleTarget.self,
              signature: .init(returnType: .objcBool, arguments: [.object, .selector, .objectPointer]))
    }

    private func key(_ selector: Selector = #selector(CoreDataSwizzleTarget.fetch(_:error:))) -> SentryTypedSwizzle.Key {
        let key = SentryTypedSwizzle.Key()
        installations.append((selector, key))
        return key
    }
}

private class CoreDataSwizzleTarget: NSObject {
    var request: NSFetchRequest<NSFetchRequestResult>?
    var result: NSArray?
    var error: NSError?
    var saveResult = false
    var errorWasNil = false
    var fetchCalls = 0
    var saveCalls = 0

    @objc dynamic func fetch(_ request: NSFetchRequest<NSFetchRequestResult>, error: NSErrorPointer) -> NSArray? {
        fetchCalls += 1
        self.request = request
        errorWasNil = error == nil
        error?.pointee = self.error
        return result
    }

    @objc dynamic func save(_ error: NSErrorPointer) -> Bool {
        saveCalls += 1
        errorWasNil = error == nil
        error?.pointee = self.error
        return saveResult
    }
}

private final class CoreDataSwizzleChild: CoreDataSwizzleTarget {}
