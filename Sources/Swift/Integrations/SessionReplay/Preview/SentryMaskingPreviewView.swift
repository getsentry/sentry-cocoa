// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import Foundation
import UIKit

@objcMembers
@_spi(Private) public final class SentryMaskingPreviewView: UIView {
    private class PreviewRenderer: SentryViewRenderer {
        func render(view: UIView) -> UIImage {
            return UIGraphicsImageRenderer(size: view.frame.size, format: .init(for: .init(displayScale: 1))).image { _ in
                // Creates a transparent image of the view size that will be used to drawn the redact regions.
                // Transparent background is the default, so no additional drawing is required.
                // Left blank on purpose
            }
        }
    }

    private let photographer: SentryViewPhotographer
    private var imageView = UIImageView()
    private var idle = true
    private var needsUpdate = false
    private var updateScheduled = false

    public var opacity: Float {
        get { return Float(imageView.alpha) }
        set { imageView.alpha = CGFloat(newValue) }
    }

    public init(redactOptions: SentryRedactOptions) {
        self.photographer = SentryViewPhotographer(
            renderer: PreviewRenderer(),
            redactOptions: redactOptions,
            enableMaskRendererV2: false,
            dateProvider: SentryDependencyContainer.sharedInstance().dateProvider
        )
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false

        imageView.sentryReplayUnmask()
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard let superview else {
            cancelPendingUpdate()
            return
        }

        frame = superview.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setNeedsPreviewUpdate()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            cancelPendingUpdate()
        } else {
            setNeedsPreviewUpdate()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsPreviewUpdate()
    }

    @available(visionOS, deprecated: 1.0)
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsPreviewUpdate()
    }

    private func setNeedsPreviewUpdate() {
        guard superview != nil, window != nil else { return }

        needsUpdate = true
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        guard needsUpdate, idle, !updateScheduled else { return }

        updateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.updateScheduled = false
            self.update()
        }
    }

    private func cancelPendingUpdate() {
        needsUpdate = false
    }

    private func update() {
        guard needsUpdate, let superview, window != nil, idle else { return }

        needsUpdate = false
        idle = false
        photographer.image(view: superview) { [weak self] maskedViewImage in
            DispatchQueue.main.async {
                guard let self else { return }

                self.idle = true
                guard self.superview != nil, self.window != nil else { return }
                guard !self.needsUpdate else {
                    self.scheduleUpdate()
                    return
                }

                self.imageView.image = maskedViewImage
            }
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
