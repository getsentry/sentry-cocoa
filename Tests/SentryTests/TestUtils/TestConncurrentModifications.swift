import Foundation

func testConcurrentModifications(asyncWorkItems: Int = 5, writeLoopCount: Int = 1_000, writeWork: @escaping (Int) -> Void, readWork: @escaping () -> Void = {}) {
    let queue = DispatchQueue(label: "testConcurrentModifications", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
    let group = DispatchGroup()
    
    for _ in 0..<asyncWorkItems {
        group.enter()
        queue.async {
            
            for i in 0...writeLoopCount {
                writeWork(i)
            }
            
            readWork()
            
            group.leave()
        }
    }
    
    queue.activate()
    group.waitWithTimeout(timeout: 500)
}
