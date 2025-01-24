#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
import Sentry
import UIKit

#if CARTHAGE || SWIFT_PACKAGE
@_implementationOnly import SentryInternal
#endif

class PreviewImageView: UIImageView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

class SentryReplayMaskPreviewUIView: UIView {
    private let photographer: SentryViewPhotographer
    private var displayLink: CADisplayLink?
    private var imageView = PreviewImageView()
    
    var opacity: Float {
        get { return Float(imageView.alpha) }
        set { imageView.alpha = CGFloat(newValue)}
    }
    
    init(redactOptions: SentryRedactOptions) {
        self.photographer = SentryViewPhotographer(renderer: PreviewRederer(), redactOptions: redactOptions)
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        imageView.isUserInteractionEnabled = false
        imageView.sentryReplayUnmask()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        if ProcessInfo.processInfo.environment[SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY] == "1" {
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        } else {
            print("[SENTRY] [WARNING] SentryReplayMaskPreview is not meant to be used in your app, only with SwiftUI Previews.")
        }
    }
    
    @objc
    private func update() {
        guard let window = self.window else { return }
        self.photographer.image(view: window) { image in
            DispatchQueue.main.async {
                self.showImage(image: image)
            }
        }
    }
    
    private func showImage(image: UIImage) {
        guard let window = super.window else { return }
        if imageView.superview != window {
            window.addSubview(imageView)
        }
        imageView.image = image
        imageView.frame = window.bounds
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

class PreviewRederer: ViewRenderer {
    func render(view: UIView) -> UIImage {
        return UIGraphicsImageRenderer(size: view.frame.size, format: .init(for: .init(displayScale: 1))).image { _ in
            // Creates a transparent image of the view size that will be used to drawn the redact regions.
            // Transparent background is the default, so no additional drawing is required.
            // Left blank on purpose
        }
    }
}

#endif
