import Foundation
import UIKit

/// Triggers a non-fully blocking app hang by blocking the app for 0.5 seconds,
/// then allowing it to draw one or two frames, and blocking it again. While the app
/// is not fully blocked because it renders a few frames, it still seems blocked to the
/// user and should be considered an app hang. We have to pick a low timer interval
/// for the Thread.sleep on the background thread, because otherwise the app renders
/// too many frames and is able to still handle user input, such as navigating to a
/// different screen.
func triggerNonFullyBlockingAppHang() {
    
    DispatchQueue.global().async {
        for _ in 0...10 {
            Thread.sleep(forTimeInterval: 0.0001)
            DispatchQueue.main.sync {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
}

/// Schedules heavy UI rendering work on the main thread in a tight loop, which causes
/// a fully blocking app hang without frames being rendered.
func triggerFullyBlockingAppHang(button: UIButton) {
    let buttonTitle = button.currentTitle
    var i = 0

    for _ in 0...5_000_000 {
        i += Int.random(in: 0...10)
        i -= 1

        button.setTitle("\(i)", for: .normal)
    }

    button.setTitle(buttonTitle, for: .normal)
}
