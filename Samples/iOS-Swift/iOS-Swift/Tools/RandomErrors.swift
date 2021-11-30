import Foundation

enum SampleError: Error {
    case bestDeveloper
    case happyCustomer
    case awesomeCentaur
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
