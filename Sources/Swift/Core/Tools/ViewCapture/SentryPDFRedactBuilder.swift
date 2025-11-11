#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
@_implementationOnly import _SentryPrivate
import PDFKit
import UIKit

@objcMembers
@_spi(Private) public class SentryPDFRedactBuilder: NSObject, SentryUIRedactBuilderProtocol {

    enum RedactionError: Error {
        case failedToCreateContext
        case failedToReadPDFDocument
        case invalidPDFContent
    }

    private let options: SentryRedactOptions

    required public init(options: SentryRedactOptions) {
        self.options = options
        super.init()
    }

    public func addIgnoreClass(_ ignoreClass: AnyClass) {
        // no-op
    }

    public func addRedactClass(_ redactClass: AnyClass) {
        // no-op
    }

    public func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {
        // no-op
    }

    public func addRedactClasses(_ redactClasses: [AnyClass]) {
        // no-op
    }

    public func setIgnoreContainerClass(_ ignoreContainerClass: AnyClass) {
        // no-op
    }

    public func setRedactContainerClass(_ redactContainerClass: AnyClass) {
        // no-op
    }

    public func redactRegionsFor(view: UIView, image: UIImage, callback: @escaping ([SentryRedactRegion]?, Error?) -> Void) {
        // Ensure UIKit access is on main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.redactRegionsFor(view: view, image: image, callback: callback)
            }
            return
        }
        
        do {
            // 1. Render the view into a PDF Context using UIKit
            let data = NSMutableData()
            let bounds = view.bounds

            // Begin PDF context
            UIGraphicsBeginPDFContextToData(data, bounds, nil)
            
            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndPDFContext()
                SentrySDKLog.error("Failed to create PDF graphics context")
                throw RedactionError.failedToCreateContext
            }
            
            // Begin PDF page
            UIGraphicsBeginPDFPage()
            
            // Render the view into the PDF context
            // Use presentation layer for accurate representation during animations
            let layer = view.layer.presentation() ?? view.layer
            layer.render(in: context)
            
            // End PDF context - this finalizes the PDF data
            UIGraphicsEndPDFContext()
            
            // Note: After rendering UIView to PDF, text becomes graphics paths,
            // not selectable text objects. Extracting text regions from the rendered
            // PDF would require parsing PDF content streams, which is complex.
            // For now, we return empty regions. This can be enhanced later with
            // PDF content stream analysis or other techniques.

            // 2. Write the PDF document data to a temporary path
            let tempUrl = URL(fileURLWithPath: "/tmp/output.pdf")
            try data.write(to: tempUrl)

            // 3. Open PDF document using PDFKit
            guard let document = PDFDocument(url: tempUrl) else {
                throw RedactionError.failedToReadPDFDocument
            }
            guard let page = document.page(at: 0) else {
                throw RedactionError.invalidPDFContent
            }
            print(page)
            callback([], nil)
        } catch {
            SentrySDKLog.error("Failed to redact view using PDF redaction: \(error)")
            callback(nil, error)
        }
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
