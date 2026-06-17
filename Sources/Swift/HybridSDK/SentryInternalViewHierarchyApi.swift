// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

/// Provides view hierarchy capture for hybrid SDKs.
public struct SentryInternalViewHierarchyApi {

    typealias Dependencies = ViewHierarchyProviderProvider

    private let viewHierarchyProvider: SentryViewHierarchyProvider?

    init(dependencies: Dependencies) {
        self.viewHierarchyProvider = dependencies.viewHierarchyProvider
    }

    /// Captures the view hierarchy of all application windows as JSON data.
    public func capture() -> Data? {
        viewHierarchyProvider?.appViewHierarchyFromMainThread()
    }
}

#endif
// swiftlint:enable missing_docs
