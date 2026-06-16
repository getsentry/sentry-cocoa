// swiftlint:disable missing_docs
import Foundation
import ObjectiveC

private let defaultMaxScopeFeatureFlags = 100
private let maxSpanFeatureFlags = 10

private enum SentryFeatureFlagAssociationKeys {
    static var scopeBuffer = 0
    static var spanBuffer = 0
}

enum SentryFeatureFlagStore {
    static func scopeBuffer(for scope: Scope) -> SentryFeatureFlagBuffer {
        if let buffer = objc_getAssociatedObject(
            scope,
            &SentryFeatureFlagAssociationKeys.scopeBuffer
        ) as? SentryFeatureFlagBuffer {
            return buffer
        }

        let buffer = SentryFeatureFlagBuffer(
            maxSize: defaultMaxScopeFeatureFlags,
            overflowBehavior: .dropOldest
        )
        setScopeBuffer(buffer, for: scope)
        return buffer
    }

    static func spanBuffer(for span: Span) -> SentryFeatureFlagBuffer {
        let object = span as AnyObject
        if let buffer = objc_getAssociatedObject(
            object,
            &SentryFeatureFlagAssociationKeys.spanBuffer
        ) as? SentryFeatureFlagBuffer {
            return buffer
        }

        let buffer = SentryFeatureFlagBuffer(
            maxSize: maxSpanFeatureFlags,
            overflowBehavior: .rejectNew
        )
        setSpanBuffer(buffer, for: span)
        return buffer
    }

    static func serializedScopeFeatureFlags(from scope: Scope) -> [String: Any]? {
        guard let buffer = objc_getAssociatedObject(
            scope,
            &SentryFeatureFlagAssociationKeys.scopeBuffer
        ) as? SentryFeatureFlagBuffer else {
            return nil
        }
        return buffer.serializeForContext()
    }

    static func serializedSpanFeatureFlagData(from span: Span) -> [String: Any] {
        let object = span as AnyObject
        guard let buffer = objc_getAssociatedObject(
            object,
            &SentryFeatureFlagAssociationKeys.spanBuffer
        ) as? SentryFeatureFlagBuffer else {
            return [:]
        }
        return buffer.serializeForSpanData()
    }

    static func copyFeatureFlags(from source: Scope, to target: Scope) {
        guard let sourceBuffer = objc_getAssociatedObject(
            source,
            &SentryFeatureFlagAssociationKeys.scopeBuffer
        ) as? SentryFeatureFlagBuffer else {
            removeScopeBuffer(from: target)
            return
        }
        setScopeBuffer(sourceBuffer.copyBuffer(), for: target)
    }

    static func clearFeatureFlags(from scope: Scope) {
        guard let buffer = objc_getAssociatedObject(
            scope,
            &SentryFeatureFlagAssociationKeys.scopeBuffer
        ) as? SentryFeatureFlagBuffer else {
            return
        }
        buffer.removeAll()
    }

    private static func setScopeBuffer(_ buffer: SentryFeatureFlagBuffer, for scope: Scope) {
        objc_setAssociatedObject(
            scope,
            &SentryFeatureFlagAssociationKeys.scopeBuffer,
            buffer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func removeScopeBuffer(from scope: Scope) {
        objc_setAssociatedObject(
            scope,
            &SentryFeatureFlagAssociationKeys.scopeBuffer,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func setSpanBuffer(_ buffer: SentryFeatureFlagBuffer, for span: Span) {
        objc_setAssociatedObject(
            span as AnyObject,
            &SentryFeatureFlagAssociationKeys.spanBuffer,
            buffer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

extension Scope {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        SentryFeatureFlagStore.scopeBuffer(for: self).add(name: name, value: result)
    }
}

extension Span {
    @_spi(Private) public func addFeatureFlag(name: String, result: Bool) {
        SentryFeatureFlagStore.spanBuffer(for: self).add(name: name, value: result)
    }
}

@_spi(Private)
@objc(SentryFeatureFlagObjCHelper)
public final class SentryFeatureFlagObjCHelper: NSObject {
    @objc(copyFeatureFlagsFromScope:toScope:)
    public static func copyFeatureFlags(from source: Scope, to target: Scope) {
        SentryFeatureFlagStore.copyFeatureFlags(from: source, to: target)
    }

    @objc(clearFeatureFlagsFromScope:)
    public static func clearFeatureFlags(from scope: Scope) {
        SentryFeatureFlagStore.clearFeatureFlags(from: scope)
    }

    @objc(serializedScopeFeatureFlagsFromScope:)
    public static func serializedScopeFeatureFlags(from scope: Scope) -> [String: Any]? {
        SentryFeatureFlagStore.serializedScopeFeatureFlags(from: scope)
    }

    @objc(serializedSpanFeatureFlagDataFromSpan:)
    public static func serializedSpanFeatureFlagData(from span: Span) -> [String: Any] {
        SentryFeatureFlagStore.serializedSpanFeatureFlagData(from: span)
    }
}
// swiftlint:enable missing_docs
