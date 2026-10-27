import Foundation
import SentrySampleShared
import SentrySwift
import UIKit

/// Slows down every launch while `SentrySDKOverrides.MetricKit.slowLaunch` is on, so MetricKit
/// reports an `MXAppLaunchDiagnostic`.
enum MetricKitAppLaunchStressor {
    private static let duration: TimeInterval = 8

    /// Call during launch, before the first frame is drawn.
    static func runIfEnabled() {
        guard SentrySDKOverrides.MetricKit.slowLaunch.boolValue else {
            return
        }

        guard let imageData = Bundle.main.url(forResource: "Tongariro", withExtension: "jpg")
            .flatMap({ try? Data(contentsOf: $0) }) else {
            SentrySDK.logger.error(
                "MetricKit app launch stressor image could not be loaded",
                attributes: ["stressor": "app_launch"]
            )
            return
        }

        SentrySDK.logger.info(
            "MetricKit app launch stressor started",
            attributes: [
                "stressor": "app_launch",
                "duration_seconds": duration,
                "workload": "image_decoding"
            ]
        )

        let endTime = Date().addingTimeInterval(duration)
        while Date() < endTime {
            autoreleasepool {
                _ = UIImage(data: imageData)?.preparingForDisplay()
            }
        }

        SentrySDK.logger.info(
            "MetricKit app launch stressor completed",
            attributes: [
                "stressor": "app_launch",
                "duration_seconds": duration,
                "workload": "image_decoding"
            ]
        )
    }
}
