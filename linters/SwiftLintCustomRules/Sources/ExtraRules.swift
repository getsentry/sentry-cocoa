import SwiftLintCore

public func extraRules() -> [any Rule.Type] {
    [
        StandaloneObjCExtensionRule.self,
    ]
}
