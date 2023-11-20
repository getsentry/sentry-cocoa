import Foundation

func triggerANRFillingRunLoop(button: UIButton) {
    let dispatchQueue = DispatchQueue(label: "ANR")
    
    let buttonTitle = button.currentTitle
    var i = 0

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
        for _ in 0...30 {
            i += Int.random(in: 0...10)
            i -= 1

            DispatchQueue.main.async {
                sleep(timeout: 0.1)
                button.setTitle("Title \(i)", for: .normal)
            }
        }

        DispatchQueue.main.sync {
            button.setTitle(buttonTitle, for: .normal)
        }
    }
}
