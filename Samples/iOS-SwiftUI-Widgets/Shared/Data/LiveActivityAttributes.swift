import Foundation

#if canImport(ActivityKit)

import ActivityKit

struct LiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable & Hashable {
        let timestamp: Date
    }
    
    let id: String
}

#endif // canImport(ActivityKit)
