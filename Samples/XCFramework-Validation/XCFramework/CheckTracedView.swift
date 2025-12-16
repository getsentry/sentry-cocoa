import Foundation
import SentrySwiftUI
import SwiftUI

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

extension View {
    public func traceView(_ viewName: String? = nil) -> some View {
        sentryTrace(viewName)
    }
}
