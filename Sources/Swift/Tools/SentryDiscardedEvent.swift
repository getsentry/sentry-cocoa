@_implementationOnly import _SentryPrivate
import Foundation

@_spi(Private) @objc public enum SentryDiscardReasonSwift: UInt {
  case beforeSend
  case eventProcessor
  case sampleRate
  case networkError
  case queueOverflow
  case cacheOverflow
  case rateLimitBackoff
  case insufficientData
  
  func toObjcEnum() -> SentryDiscardReason {
    switch self {
    case .beforeSend:
      return .beforeSend
    case .eventProcessor:
        return .eventProcessor
    case .sampleRate:
        return .sampleRate
    case .networkError:
        return .networkError
    case .queueOverflow:
        return .queueOverflow
    case .cacheOverflow:
        return .cacheOverflow
    case .rateLimitBackoff:
        return .rateLimitBackoff
    case .insufficientData:
        return .insufficientData
    }
  }
}

@_spi(Private) @objc public enum SentryDataCategorySwift: UInt {
  case all
  case `default`
  case error
  case session
  case transaction
  case attachment
  case userFeedback
  case profile
  case metricBucket
  case replay
  case profileChunk
  case span
  case feedback
  case logItem
  case unknown
  
  // swiftlint:disable cyclomatic_complexity
  func toObjcEnum() -> SentryDataCategory {
    switch self {
    case .all:
      return .all
    case .default:
        return .default
    case .error:
        return .error
    case .session:
        return .session
    case .transaction:
        return .transaction
    case .attachment:
        return .attachment
    case .userFeedback:
        return .userFeedback
    case .profile:
        return .profile
    case .metricBucket:
        return .metricBucket
    case .replay:
        return .replay
    case .profileChunk:
        return .profileChunk
    case .span:
        return .span
    case .feedback:
        return .feedback
    case .logItem:
        return .logItem
    case .unknown:
        return .unknown
    }
  }
  // swiftlint:enable cyclomatic_complexity
}

@objcMembers
@_spi(Private)
public final class SentryDiscardedEvent: NSObject, SentrySerializable {
    
    let reason: SentryDiscardReason
    let category: SentryDataCategory
    public let quantity: UInt
    
    public init(reason: SentryDiscardReasonSwift, category: SentryDataCategorySwift, quantity: UInt) {
        self.reason = reason.toObjcEnum()
        self.category = category.toObjcEnum()
        self.quantity = quantity
        super.init()
    }
    
    public func serialize() -> [String: Any] {
        return [
            "reason": nameForSentryDiscardReason(reason),
            "category": nameForSentryDataCategory(category),
            "quantity": quantity
        ]
    }
}
