import Foundation

enum SampleError: Error {
    case bestDeveloper
    case happyCustomer
    case awesomeCentaur
}

extension SampleError: CustomNSError {
    var errorUserInfo: [String: Any] {
        func getDebugDescription() -> String {
            switch self {
            case SampleError.bestDeveloper:
                return  "bestDeveloper"
            case .happyCustomer:
                return  "happyCustomer"
            case .awesomeCentaur:
                return "awesomeCentaur"
            }
        }
        
        return [NSDebugDescriptionErrorKey: getDebugDescription()]
    }
}

class RandomErrorGenerator {
    
    static func generate() throws {
        let random = Int.random(in: 0...2)
        switch random {
        case 0:
            throw SampleError.bestDeveloper
        case 1:
            throw SampleError.happyCustomer
        case 2:
            throw SampleError.awesomeCentaur
        default:
            throw SampleError.bestDeveloper
        }
    }
}
