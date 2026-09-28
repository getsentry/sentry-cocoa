import SwiftLintCore
import SwiftLintExtraRules
import Testing

@Suite
struct StandaloneObjCExtensionRuleTests {
    @Test(arguments: [
        "@objc extension Foo {}",
        "extension Foo { @objc func bar() {} }",
        """
        extension Foo {
            @objc func bar() {}
        }
        """,
        """
        extension Foo { @objc
            func bar() {}
        }
        """,
        """
        @objc
        @available(iOS 13, *)
        extension Foo {}
        """,
        """
        @objc protocol P {}
        extension Foo: P {}
        """,
        """
        protocol P {}
        @objc protocol Q {}
        extension Foo: P & Q {}
        """,
        """
        @objc protocol P {}
        extension Foo: @retroactive P {}
        """,
        """
        extension Options {
            @objc(initWithDictionary:didFailWithError:)
            public convenience init?(dictionary: [String: Any], didFailWithError error: NSErrorPointer) {}
        }
        """,
        "extension Foo { @objc var bar: Int { 0 } }",
        "extension Foo { @objc subscript(i: Int) -> Int { 0 } }",
        "extension Foo { @objc class func bar() {} }",
        "extension Foo { @objc static func bar() {} }",
        """
        extension Foo {
        #if os(iOS)
            @objc func bar() {}
        #endif
        }
        """,
        "@_spi(Private) @objc public extension Foo {}",
        "package extension Foo { @objc func bar() {} }",
    ])
    func flagsStandaloneCategory(_ code: String) {
        let violations = lint(code)
        #expect(!violations.isEmpty)
        #expect(violations.contains { $0.reason.contains("Triggering code:") })
    }

    @Test(arguments: [
        """
        @objc class Dummy: NSObject {}
        @objc extension Foo {}
        """,
        """
        nonisolated(unsafe) class Dummy: NSObject {}
        @objc extension Foo {}
        """,
        """
        struct Dummy {}
        @objc extension Foo {}
        """,
        """
        @objc protocol P { func x() }
        extension P { func x() {} }
        """,
        "extension Foo { func bar() {} }",
        "extension Foo { @objc class Nested: NSObject {} }",
        """
        enum Dummy { case a }
        @objc extension Foo {}
        """,
        """
        actor Dummy {}
        @objc extension Foo {}
        """,
    ])
    func allowsNonCategoryOrAnchoredFile(_ code: String) {
        #expect(lint(code).isEmpty)
    }

    private func lint(_ code: String) -> [StyleViolation] {
        rule.validate(file: SwiftLintFile(contents: code))
    }
}

private let rule: any Rule = extraRules()
    .first { $0.description.identifier == "standalone_objc_extension" }!
    .init()
