import Sentry
public extension Breadcrumb {
    static func navigation(screen: String, date: Date? = nil) -> Breadcrumb {
        let result = Breadcrumb(level: .info, category: "navigation")
        
        result.type = "navigation"
        result.timestamp = date
        result.data = ["screen": screen]
        
        return result
    }
    
    static func custom(date: Date? = nil) -> Breadcrumb {
        let result = Breadcrumb(level: .info, category: "custom")
        
        result.timestamp = date
        
        return result
    }
}
