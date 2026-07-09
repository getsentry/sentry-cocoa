@testable import SentryObjCCompat
import SentryTestUtilsDynamic
import XCTest

final class AccessorTests: XCTestCase {

    func testInitWithValue_whenValueRead_shouldReturnInitialValue() {
        // -- Arrange --
        let accessor = Accessor(42)

        // -- Act --
        let result = accessor.value

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    func testValue_whenStandaloneValueSet_shouldReturnNewValue() {
        // -- Arrange --
        let accessor = Accessor(42)

        // -- Act --
        accessor.value = 7

        // -- Assert --
        XCTAssertEqual(accessor.value, 7)
    }

    func testInitWithClosures_whenValueRead_shouldCallGetter() {
        // -- Arrange --
        let invocations = ObjCInvocations()
        let accessor = Accessor(
            get: {
                invocations.record([:])
                return "value"
            },
            set: { (_: String) in }
        )

        // -- Act --
        let result = accessor.value

        // -- Assert --
        XCTAssertEqual(result, "value")
        XCTAssertEqual(invocations.count, 1)
    }

    func testValue_whenClosureBackedValueSet_shouldCallSetter() {
        // -- Arrange --
        var storage = "initial"
        let invocations = ObjCInvocations()
        let accessor = Accessor(
            get: { storage },
            set: {
                invocations.record(["value": $0])
                storage = $0
            }
        )

        // -- Act --
        accessor.value = "updated"

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?["value"] as? String, "updated")
        XCTAssertEqual(storage, "updated")
        XCTAssertEqual(accessor.value, "updated")
    }

    func testInitWithRootKeyPath_whenValueRead_shouldReturnRootProperty() {
        // -- Arrange --
        let root = Root(value: 42)
        let accessor = Accessor(root: root, keyPath: \.value)

        // -- Act --
        let result = accessor.value

        // -- Assert --
        XCTAssertEqual(result, 42)
    }

    func testValue_whenRootKeyPathBackedValueSet_shouldUpdateRootProperty() {
        // -- Arrange --
        let invocations = ObjCInvocations()
        let root = Root(value: 42, valueInvocations: invocations)
        let accessor = Accessor(root: root, keyPath: \.value)

        // -- Act --
        accessor.value = 7

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?["value"] as? Int, 7)
        XCTAssertEqual(root.value, 7)
        XCTAssertEqual(accessor.value, 7)
    }

    func testChild_whenValueRead_shouldReturnNestedValue() {
        // -- Arrange --
        let accessor = Accessor(Parent(child: Child(value: 42)))
        let child = accessor.child(\.child)

        // -- Act --
        let result = child.value

        // -- Assert --
        XCTAssertEqual(result, Child(value: 42))
    }

    func testChild_whenChildValueSet_shouldUpdateParentValue() {
        // -- Arrange --
        let accessor = Accessor(Parent(child: Child(value: 42)))
        let child = accessor.child(\.child)

        // -- Act --
        child.value = Child(value: 7)

        // -- Assert --
        XCTAssertEqual(accessor.value.child, Child(value: 7))
        XCTAssertEqual(child.value, Child(value: 7))
    }

    func testChild_whenNestedPropertySet_shouldUpdateParentValue() {
        // -- Arrange --
        let accessor = Accessor(Parent(child: Child(value: 42)))
        let value = accessor.child(\.child).child(\.value)

        // -- Act --
        value.value = 7

        // -- Assert --
        XCTAssertEqual(accessor.value.child.value, 7)
        XCTAssertEqual(value.value, 7)
    }

    func testChild_whenRootKeyPathBackedNestedPropertySet_shouldUpdateRootProperty() {
        // -- Arrange --
        let invocations = ObjCInvocations()
        let root = Root(parent: Parent(child: Child(value: 42)), parentInvocations: invocations)
        let accessor = Accessor(root: root, keyPath: \.parent)
        let value = accessor.child(\.child).child(\.value)

        // -- Act --
        value.value = 7

        // -- Assert --
        XCTAssertEqual(invocations.count, 1)
        XCTAssertEqual(invocations.first?["childValue"] as? Int, 7)
        XCTAssertEqual(root.parent.child.value, 7)
        XCTAssertEqual(accessor.value.child.value, 7)
        XCTAssertEqual(value.value, 7)
    }
}

private final class Root {
    var valueInvocations: ObjCInvocations?
    var parentInvocations: ObjCInvocations?

    var value: Int {
        didSet { valueInvocations?.record(["value": value]) }
    }

    var parent: Parent {
        didSet { parentInvocations?.record(["childValue": parent.child.value]) }
    }

    init(
        value: Int = 0,
        parent: Parent = Parent(child: Child(value: 0)),
        valueInvocations: ObjCInvocations? = nil,
        parentInvocations: ObjCInvocations? = nil
    ) {
        self.value = value
        self.parent = parent
        self.valueInvocations = valueInvocations
        self.parentInvocations = parentInvocations
    }
}

private struct Parent: Equatable {
    var child: Child
}

private struct Child: Equatable {
    var value: Int
}
