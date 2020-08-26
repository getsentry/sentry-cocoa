import Foundation

class Triple<A, B, C> {
    let first: A
    let second: B
    let third: C
    
    init(_ first: A, _ second: B, _ third: C) {
        self.first = first
        self.second = second
        self.third = third
    }
}
