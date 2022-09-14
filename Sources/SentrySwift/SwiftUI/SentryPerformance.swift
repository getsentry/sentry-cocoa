import Foundation
import SentryObjc
import SwiftUI

@available(iOS 13, macOS 10.15, *)
public struct SentryPerformance: ViewModifier {
    
    public func body(content: Content) -> some View {
        return content
    }
}

@available(iOS 13, macOS 10.15, *)
public extension View {
    func sentryTransaction() -> some View {
        modifier(SentryPerformance())
    }
}
