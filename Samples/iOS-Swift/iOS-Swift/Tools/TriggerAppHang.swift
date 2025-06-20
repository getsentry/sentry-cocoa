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

/// Triggers a fully blocking app hang by blocking the main thread for around 5 seconds.
func triggerFullyBlockingAppHangThreadSleeping() {
    sleep(5)
}

// Blocks the main thread for 5 seconds while decoding an image in a loop.
@available(iOS 15.0, *)
func triggerFullyBlockingAppHangWithImageDecoding() {

    let currentTime = Date()
    let timeToFinishUpdatingUI = currentTime.addingTimeInterval(5)

    while timeToFinishUpdatingUI > Date() {

        if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg"),
           let imageData = FileManager.default.contents(atPath: path) {

            if let image = UIImage(data: imageData) {
                image.preparingForDisplay()
            }
        }
    }
}
