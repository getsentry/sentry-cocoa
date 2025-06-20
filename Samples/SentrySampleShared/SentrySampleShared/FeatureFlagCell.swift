#if !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)

import UIKit

protocol FeatureFlagCell: UITableViewCell {
    func configure(with override: any SentrySDKOverride)
}

#endif // !os(macOS) && !os(tvOS) && !os(watchOS) && !os(visionOS)
