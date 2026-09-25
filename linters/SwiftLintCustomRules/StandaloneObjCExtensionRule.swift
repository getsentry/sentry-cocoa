import SwiftLintCore
import SwiftSyntax

/// Flags Swift files whose only type-level content is an Objective-C category.
///
/// An `@objc` extension, an extension with `@objc` members, or an extension that
/// conforms to an `@objc` protocol declared in the same file compiles to an ObjC
/// category. If that file has no class/struct/enum/actor, the linker strips the
/// object file from static builds — the category methods disappear at runtime.
/// See #6125 among other issues.
///
/// The fix is to add a dummy `@objc` NSObject subclass in the same file and
/// reference it from SentrySDKInternal (see PlaceholderProcessInfoClass) OR
/// move the reference into a file that contains a non-objc category type
/// referenced somewhere in the codebase.
@SwiftSyntaxRule
struct StandaloneObjCExtensionRule: Rule {
    var configuration = SeverityConfiguration<Self>(.error)

    static let description = RuleDescription(
        identifier: "standalone_objc_extension",
        name: "Standalone ObjC Extension",
        description: """
            An @objc extension (or an extension with @objc members) in a file with no \
            class, struct, enum, or actor is stripped from static builds
            """,
        kind: .lint,
        nonTriggeringExamples: [
            Example(code: "class Dummy: NSObject {}"),
            Example(code: """
                @objc class Dummy: NSObject {}
                @objc extension Foo {}
                """),
            Example(code: """
                struct Dummy {}
                @objc extension Foo {}
                """),
            Example(code: """
                enum Dummy { case a }
                extension Foo {
                    @objc func bar() {}
                }
                """),
            Example(code: """
                actor Dummy {}
                @objc extension Foo {}
                """),
            Example(code: """
                nonisolated(unsafe) class Dummy: NSObject {}
                @objc extension Foo {}
                """),
            Example(code: "extension Foo { func bar() {} }"),
            Example(code: "@objc protocol P { func x() }"),
            Example(code: """
                @objc protocol P { func x() }
                extension P { func x() {} }
                """),
            Example(code: "extension Foo { @objc class Nested: NSObject {} }"),
        ],
        triggeringExamples: [
            Example(code: "↓@objc extension Foo {}"),
            Example(code: "↓@objc extension Foo { func bar() {} }"),
            Example(code: """
                ↓extension Foo {
                    @objc func bar() {}
                }
                """),
            Example(code: "↓extension Foo { @objc func bar() {} }"),
            Example(code: """
                ↓extension Foo { @objc
                    func bar() {}
                }
                """),
            Example(code: """
                ↓extension Foo {
                    @objc
                    func bar() {}
                }
                """),
            Example(code: """
                ↓extension Options {
                    @objc(initWithDictionary:didFailWithError:)
                    public convenience init?(dictionary: [String: Any], didFailWithError error: NSErrorPointer) {}
                }
                """),
            Example(code: """
                ↓@objc
                @available(iOS 13, *)
                extension Foo {}
                """),
            Example(code: """
                @objc protocol P {}
                ↓extension Foo: P {}
                """),
            Example(code: """
                protocol P {}
                @objc protocol Q {}
                ↓extension Foo: P & Q {}
                """),
            Example(code: """
                @objc protocol P {}
                ↓extension Foo: @retroactive P {}
                """),
            Example(code: """
                extension Foo { func a() {} }
                ↓extension Bar {
                    @objc func b() {}
                }
                """),
            Example(code: """
                typealias Foo = Int
                ↓@objc extension Bar {}
                """),
        ]
    )
}

private extension StandaloneObjCExtensionRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
            let decls = flatten(node.statements)

            let protocolNames = Set(decls.compactMap { ProtocolDeclSyntax($0)?.name.text })
            let objcProtocolNames = Set(decls.compactMap { decl -> String? in
                guard let proto = ProtocolDeclSyntax(decl), proto.attributes.containsObjC else {
                    return nil
                }
                return proto.name.text
            })
            let hasConcreteType = decls.contains { decl in
                ClassDeclSyntax(decl) != nil
                    || StructDeclSyntax(decl) != nil
                    || EnumDeclSyntax(decl) != nil
                    || ActorDeclSyntax(decl) != nil
            }

            guard !hasConcreteType else {
                return .skipChildren
            }

            for decl in decls {
                guard let ext = ExtensionDeclSyntax(decl), ext.isObjCCategory(
                    protocolNames: protocolNames,
                    objcProtocolNames: objcProtocolNames
                ) else {
                    continue
                }
                violations.append(
                    ReasonedRuleViolation(
                        position: ext.positionAfterSkippingLeadingTrivia,
                        reason: """
                            An @objc extension (or an extension with @objc members) in a file with no \
                            class, struct, enum, or actor is stripped from static builds\n\n\
                            Triggering code:\n\
                            \(ext.triggerSnippet)
                            """
                    )
                )
            }

            return .skipChildren
        }
    }
}

private func flatten(_ statements: CodeBlockItemListSyntax) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    for item in statements {
        if let ifConfig = IfConfigDeclSyntax(item.item) {
            decls.append(contentsOf: flatten(ifConfig))
        } else if let decl = DeclSyntax(item.item) {
            decls.append(decl)
        }
    }
    return decls
}

private func flatten(_ config: IfConfigDeclSyntax) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    for clause in config.clauses {
        switch clause.elements {
        case .statements(let statements)?:
            decls.append(contentsOf: flatten(statements))
        case .decls(let members)?:
            decls.append(contentsOf: flatten(members))
        default:
            break
        }
    }
    return decls
}

private func flatten(_ members: MemberBlockItemListSyntax) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    for member in members {
        if let ifConfig = IfConfigDeclSyntax(member.decl) {
            decls.append(contentsOf: flatten(ifConfig))
        } else {
            decls.append(member.decl)
        }
    }
    return decls
}

private extension ExtensionDeclSyntax {
    var triggerSnippet: String {
        let lines = trimmedDescription.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(12)
            .map(String.init)
        return lines.joined(separator: "\n")
    }

    func isObjCCategory(protocolNames: Set<String>, objcProtocolNames: Set<String>) -> Bool {
        if let name = extendedType.simpleName, protocolNames.contains(name) {
            return false
        }
        if attributes.containsObjC {
            return true
        }
        if flatten(memberBlock.members).contains(where: \.isObjCMember) {
            return true
        }
        return inheritedTypeNames.contains(where: objcProtocolNames.contains)
    }

    var inheritedTypeNames: [String] {
        guard let inheritanceClause else {
            return []
        }
        return inheritanceClause.inheritedTypes.flatMap { $0.type.conformanceNames }
    }
}

private extension DeclSyntax {
    var isObjCMember: Bool {
        if let function = FunctionDeclSyntax(self) {
            return function.attributes.containsObjC
        }
        if let initializer = InitializerDeclSyntax(self) {
            return initializer.attributes.containsObjC
        }
        if let variable = VariableDeclSyntax(self) {
            return variable.attributes.containsObjC
        }
        if let subscriptDecl = SubscriptDeclSyntax(self) {
            return subscriptDecl.attributes.containsObjC
        }
        return false
    }
}

private extension AttributeListSyntax {
    var containsObjC: Bool {
        contains { element in
            if let attribute = AttributeSyntax(element), attribute.isObjC {
                return true
            }
            if let config = IfConfigDeclSyntax(element) {
                return config.clauses.contains { clause in
                    if case .attributes(let attributes)? = clause.elements {
                        return attributes.containsObjC
                    }
                    return false
                }
            }
            return false
        }
    }
}

private extension AttributeSyntax {
    var isObjC: Bool {
        attributeName.as(IdentifierTypeSyntax.self)?.name.text == "objc"
    }
}

private extension TypeSyntax {
    var simpleName: String? {
        if let identifier = self.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = self.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        if let attributed = self.as(AttributedTypeSyntax.self) {
            return attributed.baseType.simpleName
        }
        return nil
    }

    var conformanceNames: [String] {
        if let identifier = self.as(IdentifierTypeSyntax.self) {
            return [identifier.name.text]
        }
        if let member = self.as(MemberTypeSyntax.self) {
            return [member.name.text]
        }
        if let composition = self.as(CompositionTypeSyntax.self) {
            return composition.elements.flatMap(\.type.conformanceNames)
        }
        if let attributed = self.as(AttributedTypeSyntax.self) {
            return attributed.baseType.conformanceNames
        }
        return []
    }
}
