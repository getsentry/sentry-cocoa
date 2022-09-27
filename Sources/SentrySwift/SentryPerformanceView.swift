import Foundation
import SentryObjc
import SwiftUI

@available(iOS 13, macOS 10.15, *)
public struct SentryPerformanceView<Content: View>: View {
    
    @ViewBuilder let content : () -> Content
    let name: String?
    
    public init(name: String? = nil, @ViewBuilder content : @escaping () -> Content) {
        self.content = content
        self.name = name
    }
    
    static func extractName(content: Any) -> String {
        var result = String(describing: type(of: content))
        
        if let index = result.firstIndex(of: "<") {
            result = String(result[result.startIndex ..< index])
        }
        
        return result
    }
    
    public var body: some View {
        
        let name = self.name ?? String(describing: Content.self)
        print("### Body of \(name)")
        
        let id = SentryPerformanceTracker.shared.startSpan(withName: name, nameSource: .component, operation: "ui")
        SentryPerformanceTracker.shared.pushActiveSpan(id)
        
        let result = self.content()
        
        SentryPerformanceTracker.shared.popActiveSpan()
        SentryPerformanceTracker.shared.finishSpan(id)
        print("### end of \(name)")
        return result
        
    }
}

@available(iOS 13, macOS 10.15, *)
public extension View {
    func sentryTransaction(_ transactionName: String? = nil) -> some View {
        return SentryPerformanceView (name: transactionName) {
            return self
        }
    }
}
