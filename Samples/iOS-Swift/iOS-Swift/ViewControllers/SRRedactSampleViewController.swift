import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit
import WebKit
import AVFoundation

enum RedactRegionType {
    case redact
    case clipOut
    case clipBegin
    case clipEnd
}


struct RedactRegion {
    let size: CGSize
    let transform: CGAffineTransform
    let type: RedactRegionType
    let color: UIColor?
    
    init(size: CGSize, transform: CGAffineTransform, type: RedactRegionType, color: UIColor? = nil) {
        self.size = size
        self.transform = transform
        self.type = type
        self.color = color
    }
}

class SRRedactSampleViewController: UIViewController {
    private var ignoreClassesIdentifiers: Set<ObjectIdentifier> = []
    private var redactClassesIdentifiers: Set<ObjectIdentifier> = []
      
    @IBOutlet var notRedactedView: UIView!
    
    @IBOutlet var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notRedactedView.backgroundColor = .green
        notRedactedView.transform = CGAffineTransform(rotationAngle: 45 * .pi / 180.0)        
        SentryRedactViewHelper.ignoreView(notRedactedView.subviews.first!)
        
        var redactClasses = [AnyClass]()
        redactClasses += [ UILabel.self, UITextView.self, UITextField.self, UIImageView.self, WKWebView.self, UIWebView.self ]
        
        redactClasses += ["_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
         "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
         "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer"
        ].compactMap(NSClassFromString(_:))
        redactClasses += [ WKWebView.self, UIWebView.self ]
        
        ignoreClassesIdentifiers = [ ObjectIdentifier(UISlider.self), ObjectIdentifier(UISwitch.self) ]
        redactClassesIdentifiers = Set(redactClasses.map({ ObjectIdentifier($0) }))
    }
    
    func containsIgnoreClass(_ ignoreClass: AnyClass) -> Bool {
        return  ignoreClassesIdentifiers.contains(ObjectIdentifier(ignoreClass))
    }
    
    func containsRedactClass(_ redactClass: AnyClass) -> Bool {
        var currentClass: AnyClass? = redactClass
        while currentClass != nil && currentClass != UIView.self {
            if let currentClass = currentClass, redactClassesIdentifiers.contains(ObjectIdentifier(currentClass)) {
                return true
            }
            currentClass = currentClass?.superclass()
        }
        return false
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        return SentryRedactViewHelper.shouldIgnoreView(view) || containsIgnoreClass(type(of: view))
    }
    
    private func shouldRedact(view: UIView) -> Bool {
        if SentryRedactViewHelper.shouldRedactView(view) {
            return true
        }
        if let imageView = view as? UIImageView, containsRedactClass(UIImageView.self) {
            return shouldRedact(imageView: imageView)
        }
        return containsRedactClass(type(of: view))
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateRedactProcess()
    }
    
    var count = 0
    var viewHierarchy = ""
    private func animateRedactProcess() {
        guard let window = view.window,
        let targetFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        print("### \(targetFolder)")
        let screenshot = UIGraphicsImageRenderer(size: window.bounds.size, format: .init(for: .init(displayScale: 1))).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        
        count = 0
        viewHierarchy = ""
        var redactRegions = [RedactRegion]()
        
        createFrame(screenshot: screenshot, redactRegions: [], message: "START MAPPING VIEW HIERARCHY", at: targetFolder) { cont in
            
        }
        
        mapRedactRegion(fromView: window, redacting: &redactRegions, rootFrame: window.bounds, transform: .identity, saveAt: targetFolder, level: 0, screenshot: screenshot)
        createFrame(screenshot: screenshot, redactRegions: redactRegions, message: "STARTING REDACT STEPS", at: targetFolder) { cont in }
        
        redactRegions = redactRegions.reversed()
        var index = 0
        
        let finalImage = UIGraphicsImageRenderer(size: screenshot.size, format: .init(for: .init(displayScale: 1))).image(actions: { context in
            context.cgContext.addRect(CGRect(origin: CGPoint.zero, size: screenshot.size))
            context.cgContext.clip(using: .evenOdd)
            
            context.cgContext.interpolationQuality = .none
            screenshot.draw(at: .zero)
            for region in redactRegions {
                var message : String? = nil
                let rect = CGRect(origin: CGPoint.zero, size: region.size)
                var transform = region.transform
                let path = CGPath(rect: rect, transform: &transform)
                
                switch region.type {
                case .redact:
                    (region.color ?? UIColor.black).setFill()
                    context.cgContext.addPath(path)
                    context.cgContext.fillPath()
                case .clipOut:
                    context.cgContext.addRect(context.cgContext.boundingBoxOfClipPath)
                    context.cgContext.addPath(path)
                    context.cgContext.clip(using: .evenOdd)
                    message = "View is opaque, it will create a region\nwhere nothing will be drawn"
                case .clipBegin:
                    context.cgContext.saveGState()
                    context.cgContext.resetClip()
                    context.cgContext.addPath(path)
                    context.cgContext.clip()
                    message = "View is clipped\nNothing can be drawn outside the view region"
                case .clipEnd:
                    context.cgContext.restoreGState()
                    message = "End of clipped view region\nThe outside region is free to be drawn again"
                }
                
                createFrame(screenshot: context.currentImage, redactRegions: Array(redactRegions[index...].reversed()), message: message, at: targetFolder) { cont in
                    drawRect(CGRect(origin: .zero, size: region.size), transform: region.transform, at: cont)
                }
                
                index += 1
            }
        })
        
        createFrame(screenshot: finalImage, redactRegions: [], message: "END", at: targetFolder) { cont in
            
        }
        
        createVideoFromImages(sourceDirectory: targetFolder.path, destinationPath: targetFolder.appendingPathComponent("video.mp4").path, videoWidth: Int(screenshot.size.width) * 4, videoHeight: Int(screenshot.size.height))
    }
    
    
    private func createFrame(screenshot: UIImage, redactRegions: [RedactRegion], message: String? = nil, at path: URL, _ draw: (CGContext) -> Void) {
        let size = screenshot.size
        let image = UIGraphicsImageRenderer(size: CGSize(width: screenshot.size.width * 4, height: screenshot.size.height), format: .init(for: .init(displayScale: 1)) ).image { context in
         
            screenshot.draw(at: .zero)
            
            NSAttributedString(string: "VIEW HIERARCHY", attributes: [.font : UIFont(name: "Menlo-Regular", size: 26) ?? UIFont.systemFont(ofSize: 16) ])
                .draw(in: CGRect(x: size.width + 20, y: 20, width: size.width * 2 - 40, height: size.height - 80))
            
            NSAttributedString(string: viewHierarchy, attributes: [.font : UIFont(name: "Menlo-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16) ])
                .draw(in: CGRect(x: size.width + 20, y: 60, width: size.width * 2 - 40, height: size.height - 120))
            
            let rrString = redactRegions.map { "\($0.type) at: \(roundedSize($0.size)) " }.joined(separator: "\n")
            
            NSAttributedString(string: "REDACT MAP", attributes: [.font : UIFont(name: "Menlo-Regular", size: 26) ?? UIFont.systemFont(ofSize: 16) ])
                .draw(in: CGRect(x: size.width * 3 + 20, y: 20, width: size.width * 2 - 40, height: size.height - 80))
            
            NSAttributedString(string: rrString, attributes: [.font : UIFont(name: "Menlo-Regular", size: 12) ?? UIFont.systemFont(ofSize: 16) ])
                .draw(in: CGRect(x: size.width * 3 + 20, y: 60, width: size.width - 40, height: size.height - 120))
            
            if let message {
                let ps = NSMutableParagraphStyle()
                ps.alignment = .center

                UIColor.yellow.setFill()
                
                let rect = CGRect(x: size.width + 20, y: size.height - 120, width: size.width * 3 - 40, height: 80)
                context.fill(rect)
                
                let attributedString = NSAttributedString(string: message, attributes: [ .paragraphStyle: ps, .font: UIFont.boldSystemFont(ofSize: 28)])
                let textSize = attributedString.boundingRect(with: rect.size, options: .usesLineFragmentOrigin, context: nil).size
                
                let newRect = CGRect(
                    x: rect.origin.x,
                    y: rect.origin.y + (rect.size.height - textSize.height) / 2,
                    width: rect.size.width,
                    height: textSize.height
                )
                
                attributedString.draw(in: newRect)
            }
            
            draw(context.cgContext)
        }
        count += 1
        
        try? image.jpegData(compressionQuality: 0.8)?.write(to: path.appendingPathComponent(padLeftWithZeros("\(count).jpg", toLength: 7)), options: .atomic)
    }
    
    func padLeftWithZeros(_ input: String, toLength length: Int) -> String {
        let paddingCount = length - input.count
        if paddingCount > 0 {
            let padding = String(repeating: "0", count: paddingCount)
            return padding + input
        } else {
            return input
        }
    }
    
    private func roundedFrame(_ frame: CGRect) -> String {
        let x = CGFloat(Int(frame.origin.x * 100)) / 100
        let y = CGFloat(Int(frame.origin.y * 100)) / 100
        let h = CGFloat(Int(frame.size.height * 100)) / 100
        let w = CGFloat(Int(frame.size.width * 100)) / 100
        return "\(CGRect(x:x, y:y, width:w, height:h))"
    }
    
    private func roundedSize(_ size: CGSize) -> String {
        let h = CGFloat(Int(size.height * 100)) / 100
        let w = CGFloat(Int(size.width * 100)) / 100
        return "\(CGSize(width:w, height:h))"
    }
    
    private func stringForView(_ view: UIView) -> String {
        var properties = [String]()
        if view.isHidden || view.alpha == 0 {
            properties.append("Hidden")
        }
        if isOpaque(view) {
            properties.append("Opaque")
        }
        if view.clipsToBounds {
            properties.append("Clipped")
        }
        if shouldIgnore(view: view) {
            properties.append("Ignored")
        }
        return "\(type(of: view)) \(roundedFrame(view.frame)) \(properties.count > 0 ? "(\(properties.joined(separator: ", ")))": "")"
    }
    
    private func drawRect(_ rect: CGRect, transform: CGAffineTransform, at context: CGContext) {
        context.saveGState()
        UIColor.red.setStroke()
        context.setLineWidth(4)
        context.setLineDash(phase: 0, lengths: [7,7])
        context.concatenate(transform)
        context.stroke(rect)
        context.restoreGState()
    }
    
    private func mapRedactRegion(fromView view: UIView, redacting: inout [RedactRegion],
                                 rootFrame: CGRect, transform: CGAffineTransform,
                                 forceRedact: Bool = false, saveAt: URL, level: Int, screenshot: UIImage) {
        
        viewHierarchy += "\(String(repeating: "│", count: level))\(stringForView(view))\n"
        let layer = view.layer.presentation() ?? view.layer
        let newTransform = concatenateTranform(transform, with: layer)
        
        
        guard !redactClassesIdentifiers.isEmpty && !view.isHidden && view.alpha != 0 else {
            createFrame(screenshot: screenshot, redactRegions: redacting, message: "This view is hidden, skipping it", at: saveAt) { context in
                drawRect(layer.bounds, transform: newTransform, at: context)
            }
            return
        }
        
        let ignore = !forceRedact && shouldIgnore(view: view)
        let redact = forceRedact || shouldRedact(view: view)
        var enforceRedact = forceRedact
        
        if !ignore && redact {
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .redact, color: self.color(for: view)))
            guard !view.clipsToBounds else {
                createFrame(screenshot: screenshot, redactRegions: redacting, message: "Redacted view that has clipToBounds enabled\nSkipping subviews", at: saveAt) { context in
                    drawRect(layer.bounds, transform: newTransform, at: context)
                }
                return
            }
            enforceRedact = true
        } else if isOpaque(view) {
            let finalViewFrame = CGRect(origin: .zero, size: layer.bounds.size).applying(newTransform)
            if isAxisAligned(newTransform) && finalViewFrame == rootFrame {
                createFrame(screenshot: screenshot, redactRegions: redacting, message: "View is Opaque and full screen\nCleaning the Redact Map", at: saveAt) { context in
                    drawRect(layer.bounds, transform: newTransform, at: context)
                }
                redacting.removeAll()
            } else {
                redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipOut))
            }
        }
        
        guard view.subviews.count > 0 else {
            createFrame(screenshot: screenshot, redactRegions: redacting, at: saveAt) { context in
                drawRect(layer.bounds, transform: newTransform, at: context)
            }
            return
        }
        
        if view.clipsToBounds {
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipEnd))
        }
        createFrame(screenshot: screenshot, redactRegions: redacting, at: saveAt) { context in
            drawRect(layer.bounds, transform: newTransform, at: context)
        }
        for subview in view.subviews {
            mapRedactRegion(fromView: subview, redacting: &redacting, rootFrame: rootFrame, transform: newTransform, forceRedact: enforceRedact, saveAt: saveAt, level: level + 1, screenshot: screenshot)
        }
        if view.clipsToBounds {
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipBegin))
        }
    }
    
    private func concatenateTranform(_ transform: CGAffineTransform, with layer: CALayer) -> CGAffineTransform {
        let size = layer.bounds.size
        let layerMiddle = CGPoint(x: size.width * layer.anchorPoint.x, y: size.height * layer.anchorPoint.y)
        
        var newTransform = transform.translatedBy(x: layer.position.x, y: layer.position.y)
        newTransform = CATransform3DGetAffineTransform(layer.transform).concatenating(newTransform)
        return newTransform.translatedBy(x: -layerMiddle.x, y: -layerMiddle.y)
    }
    
    private func isAxisAligned(_ transform: CGAffineTransform) -> Bool {
        return transform.b == 0 && transform.c == 0
    }

    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor
    }
    
    private func isOpaque(_ view: UIView) -> Bool {
        return  view.alpha == 1 && view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) == 1
    }
    
    func createVideoFromImages(sourceDirectory: String, destinationPath: String, videoWidth: Int, videoHeight: Int) {
        let fileManager = FileManager.default
        let fileURLs = try? fileManager.contentsOfDirectory(atPath: sourceDirectory)
        
        // Filter for jpg files
        let jpgFiles = fileURLs?.filter { $0.lowercased().hasSuffix(".jpg") } ?? []
        
        // Sort the files if necessary (e.g., by filename)
        let sortedJpgFiles = jpgFiles.sorted()

        // Set up the video writer
        let videoURL = URL(fileURLWithPath: destinationPath)
        let writer = try! AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        let settings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoWidth,
            AVVideoHeightKey: videoHeight
        ] as [String : Any]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        writer.add(writerInput)

        let sourcePixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoWidth,
            kCVPixelBufferHeightKey as String: videoHeight
        ] as [String: Any]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var frameTime = CMTime(value: 0, timescale: 1)

        for jpgFile in sortedJpgFiles {
            let imagePath = "\(sourceDirectory)/\(jpgFile)"
            if let image = UIImage(contentsOfFile: imagePath),
               let cgImage = image.cgImage {

                // Create a pixel buffer from the image
                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)

                if status == kCVReturnSuccess, let buffer = pixelBuffer {
                    let context = CIContext()
                    let ciImage = CIImage(cgImage: cgImage)

                    context.render(ciImage, to: buffer)
                    adaptor.append(buffer, withPresentationTime: frameTime)

                    // Advance by 1 second
                    frameTime = CMTimeAdd(frameTime, CMTimeMake(value: 1, timescale: 1))
                }
            }
            try? FileManager.default.removeItem(atPath: imagePath)
        }

        writerInput.markAsFinished()
        writer.finishWriting {
            print("### Video created at \(videoURL) ###")
        }
    }
}

@objcMembers
class SentryRedactViewHelper: NSObject {
    private static var associatedRedactObjectHandle: UInt8 = 0
    private static var associatedIgnoreObjectHandle: UInt8 = 0
    
    static func shouldRedactView(_ view: UIView) -> Bool {
        (objc_getAssociatedObject(view, &associatedRedactObjectHandle) as? NSNumber)?.boolValue ?? false
    }
    
    static func shouldIgnoreView(_ view: UIView) -> Bool {
        (objc_getAssociatedObject(view, &associatedIgnoreObjectHandle) as? NSNumber)?.boolValue ?? false
    }
    
    static func redactView(_ view: UIView) {
        objc_setAssociatedObject(view, &associatedRedactObjectHandle, true, .OBJC_ASSOCIATION_ASSIGN)
    }
    
    static func ignoreView(_ view: UIView) {
        objc_setAssociatedObject(view, &associatedIgnoreObjectHandle, true, .OBJC_ASSOCIATION_ASSIGN)
    }
}
