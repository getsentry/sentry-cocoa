import Foundation
import SentrySwiftUI
import SwiftUI

@available(iOS 15.0, *)
public struct CheckTracedView<Content: View>: View {
    public let content: () -> Content

    public init(content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        SentryTracedView {
            content()
        }
    }
}

@available(iOS 15.0, *)
extension View {
    public func traceView(_ viewName: String? = nil) -> some View {
        sentryTrace(viewName)
    }
}
