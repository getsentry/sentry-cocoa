import Foundation

func delayNonBlocking(timeout: Double = 0.2) {
    let group = DispatchGroup()
    group.enter()
    let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
    
    queue.asyncAfter(deadline: .now() + timeout) {
        group.leave()
    }
    
    group.wait()
}
