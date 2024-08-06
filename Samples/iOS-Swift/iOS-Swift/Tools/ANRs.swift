import Foundation
import UIKit

func triggerANRFillingRunLoop() {
    let dispatchQueue = DispatchQueue(label: "ANR")

    func sleep(timeout: Double) {
        let group = DispatchGroup()
        group.enter()
        let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])

        queue.asyncAfter(deadline: .now() + timeout) {
            group.leave()
        }

        group.wait()
    }
    
    dispatchQueue.async {
        for _ in 0...10 {
            sleep(timeout: 0.001)
            DispatchQueue.main.sync {
                sleep(timeout: 0.5)
            }
        }
    }

}
