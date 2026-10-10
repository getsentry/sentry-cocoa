#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
import Sentry
#endif
public extension Breadcrumb {
    static func navigation(screen: String, date: Date? = nil) -> Breadcrumb {
        let result = Breadcrumb(level: .info, category: "navigation")
        
        result.type = "navigation"
        result.timestamp = date
        result.setData(value: screen, key: "screen")
        
        return result
    }
    
    static func custom(date: Date? = nil) -> Breadcrumb {
        let result = Breadcrumb(level: .info, category: "custom")
        
        result.timestamp = date
        
        return result
    }
}
