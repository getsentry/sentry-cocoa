import Foundation
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import UIKit

/// A captured Session Replay frame.
///
/// Live captures keep the scaled `UIImage` in memory so encode can skip a disk readback.
/// Frames are still written to `imagePath` for crash durability; recovery loads disk-only
/// frames (`image == nil`) and encode falls back to reading `imagePath`.
struct SentryReplayFrame {
    let imagePath: String
    let time: Date
    let screenName: String?
    /// In-memory source for live encode. `nil` for frames loaded from disk after a crash.
    let image: UIImage?

    init(imagePath: String, time: Date, screenName: String?, image: UIImage? = nil) {
        self.imagePath = imagePath
        self.time = time
        self.screenName = screenName
        self.image = image
    }

    /// Copy used when holding a previous frame at a new segment boundary timestamp.
    func withTime(_ time: Date) -> SentryReplayFrame {
        SentryReplayFrame(imagePath: imagePath, time: time, screenName: screenName, image: image)
    }
}

/// Prefer the in-memory image; fall back to disk for crash-recovered frames.
func image(for frame: SentryReplayFrame) -> UIImage? {
    if let image = frame.image {
        return image
    }
    return UIImage(contentsOfFile: frame.imagePath)
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
