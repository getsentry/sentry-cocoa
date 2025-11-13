#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
@_implementationOnly import _SentryPrivate
import UIKit

@objcMembers
@_spi(Private) public class SentryAccessibilityRedactBuilder: NSObject, SentryRedactBuilderProtocol {
    
    private let options: SentryRedactOptions
    
    required public init(options: SentryRedactOptions) {
        self.options = options
        super.init()
    }

    // Accessibility element with its frame in image coordinates
    private struct AccessibilityElement {
        let frame: CGRect
        let label: String?
        let value: String?
        let traits: UIAccessibilityTraits
        let isSecureTextEntry: Bool
    }

    private static let processingQueue = DispatchQueue(label: "io.sentry.redaction.accessibility", qos: .userInitiated)

    // Parse accessibility elements from the view hierarchy
    private func parseAccessibilityElements(in root: UIView, image: UIImage) -> [AccessibilityElement] {
        var result: [AccessibilityElement] = []
        
        // Compute transform from view (root) coordinates into image coordinates
        let rootBounds = root.bounds
        let sx = image.size.width / max(rootBounds.width, 1)
        let sy = image.size.height / max(rootBounds.height, 1)
        // let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
        
        // Recursively parse accessibility hierarchy
        func parseHierarchy(from object: NSObject) {
            // Skip if accessibility is hidden
            guard !object.accessibilityElementsHidden else {
                return
            }
            
            // Skip hidden or zero-sized views
            if let view = object as? UIView {
                if view.isHidden || view.frame.size == .zero || view.alpha <= 0 {
                    return
                }
            }
            
            // If this object is an accessibility element, add it
            if object.isAccessibilityElement {
                // Determine the element's frame in root coordinates. Prefer presentation layers
                // for UIView-backed elements to better match in-flight animations/transitions.
                let frameInRoot: CGRect = {
                    if let view = object as? UIView {
                        let rootLayer = root.layer.presentation() ?? root.layer
                        let viewLayer = view.layer.presentation() ?? view.layer
                        let rectInViewLayer = viewLayer.bounds
                        return viewLayer.convert(rectInViewLayer, to: rootLayer)
                    } else {
                        // Fallback to accessibilityFrame (screen coordinates) for non-UIView elements
                        let accessibilityFrame = object.accessibilityFrame
                        return root.convert(accessibilityFrame, from: nil)
                    }
                }()
                
                // Scale the size to match image coordinates
                let scaledSize = CGSize(
                    width: frameInRoot.width * sx,
                    height: frameInRoot.height * sy
                )
                
                // Scale the position (center point) to match image coordinates
                let scaledCenter = CGPoint(
                    x: (frameInRoot.minX + frameInRoot.width / 2) * sx,
                    y: (frameInRoot.minY + frameInRoot.height / 2) * sy
                )
                
                // Create frame with scaled dimensions
                let frameInImage = CGRect(
                    x: scaledCenter.x - scaledSize.width / 2,
                    y: scaledCenter.y - scaledSize.height / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                // Check for secure text entry on the main thread (before moving to background queue)
                var isSecure = false
                if let textField = object as? UITextField {
                    isSecure = textField.isSecureTextEntry
                } else if let textView = object as? UITextView {
                    isSecure = textView.isSecureTextEntry
                }
                
                result.append(AccessibilityElement(
                    frame: frameInImage,
                    label: object.accessibilityLabel,
                    value: object.accessibilityValue,
                    traits: object.accessibilityTraits,
                    isSecureTextEntry: isSecure
                ))
            } else if let accessibilityElements = object.accessibilityElements as? [NSObject] { // If it has an accessibilityElements array, parse those
                for element in accessibilityElements {
                    parseHierarchy(from: element)
                }
            } else if let view = object as? UIView { // Otherwise, recurse into subviews
                // Check for modal views
                let subviewsToParse: [UIView]
                if let lastModalView = view.subviews.last(where: { $0.accessibilityViewIsModal }) {
                    subviewsToParse = [lastModalView]
                } else {
                    subviewsToParse = view.subviews
                }
                
                for subview in subviewsToParse {
                    parseHierarchy(from: subview)
                }
            }
        }
        
        parseHierarchy(from: root)
        return result
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
        // Ensure UIKit access is on main thread for deterministic debug output order
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.redactRegionsFor(view: view, image: image, callback: callback)
            }
            return
        }
        
        // Debug: print trees before enabling accessibility
        SentrySDKLog.debug("View hierarchy tree BEFORE enabling accessibility:")
        self.printViewHierarchyTree(from: view)
        SentrySDKLog.debug("Combined view+accessibility tree BEFORE enabling accessibility:")
        self.printCombinedViewAndAccessibilityTree(from: view)
        
        // Enable accessibility automation temporarily to ensure SwiftUI populates accessibility properties
        let accessibilityEnabler = SentryAccessibilityEnabler()
        let accessibilityEnabled = accessibilityEnabler.enable()
        
        if !accessibilityEnabled {
            // Log warning but continue - some elements may still be accessible
            SentrySDKLog.warning("Failed to enable accessibility automation. SwiftUI text may not be detected.")
        }
        
        // Give the system a moment to update accessibility properties
        // SwiftUI needs time to populate accessibility info after automation is enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                accessibilityEnabler.disable()
                return
            }
            
            // Debug: print combined tree after enabling accessibility (post-delay for population)
            SentrySDKLog.debug("Combined view+accessibility tree AFTER enabling accessibility:")
            self.printCombinedViewAndAccessibilityTree(from: view)
            
            // Capture a lightweight snapshot of accessibility elements on the main thread
            let elements = self.parseAccessibilityElements(in: view, image: image)
            
            // Disable accessibility automation as soon as we're done capturing
            accessibilityEnabler.disable()

            // Process on a background queue to avoid blocking UI
            Self.processingQueue.async {
                var regions: [SentryRedactRegion] = []

                for element in elements {
                    // Determine if we should redact this element
                    let shouldRedact = self.shouldRedact(element: element)
                    
                    if shouldRedact {
                        let rect = element.frame
                        let size = rect.size
                        
                        // The transform should position the center of the rect
                        // Then offset by -anchorPoint (which is -size/2 for centered anchor)
                        let center = CGPoint(x: rect.midX, y: rect.midY)
                        let anchorOffset = CGPoint(x: size.width / 2, y: size.height / 2)
                        
                        var transform = CGAffineTransform(translationX: center.x, y: center.y)
                        transform = transform.translatedBy(x: -anchorOffset.x, y: -anchorOffset.y)
                        
                        let description = [element.label, element.value]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        
                        regions.append(SentryRedactRegion(
                            size: size,
                            transform: transform,
                            type: .redact,
                            color: nil, // Let the renderer choose the color
                            name: description.isEmpty ? "Accessibility Element" : description
                        ))
                    }
                }

                DispatchQueue.main.async {
                    callback(regions, nil)
                }
            }
        }
    }
    
    // Determine if an accessibility element should be redacted
    private func shouldRedact(element: AccessibilityElement) -> Bool {
        let traits = element.traits
        
        // Always redact secure text fields
        if element.isSecureTextEntry {
            return true
        }
        
        // If maskAllText is enabled, redact all text-containing elements
        if options.maskAllText {
            // Check if element has static text, text entry, or keyboard key traits
            let isTextElement = traits.contains(.staticText) ||
                                traits.contains(.keyboardKey) ||
                                traits.contains(.searchField) ||
                                (element.label != nil || element.value != nil)
            return isTextElement
        }
        
        return false
    }
    
    // MARK: - Debug helpers
    
    /// Prints a minimal tree of the `UIView` hierarchy similar to the `tree` CLI.
    /// Runs on the main thread for UIKit safety.
    ///
    /// Example output:
    /// ├─ UIView(frame: {{0, 0}, {390, 844}})
    /// │  ├─ UILabel(frame: {{16, 24}, {200, 20}}, ax=1, "Title")
    /// │  └─ UIButton(frame: {{16, 60}, {80, 32}}, ax=1, "Login")
    ///
    /// - Parameters:
    ///   - root: The root view to start printing from.
    ///   - maxDepth: Optional maximum depth to traverse.
    public func printViewHierarchyTree(from root: UIView, maxDepth: Int = 64) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.printViewHierarchyTree(from: root, maxDepth: maxDepth)
            }
            return
        }
        
        func describeView(_ view: UIView) -> String {
            let typeName = String(describing: type(of: view))
            let frameStr = "frame: \(NSCoder.string(for: view.frame))"
            let isAX = view.isAccessibilityElement ? "1" : "0"
            let label = (view.accessibilityLabel?.isEmpty == false) ? ", \"\(view.accessibilityLabel!)\"" : ""
            return "\(typeName)(\(frameStr), ax=\(isAX)\(label))"
        }
        
        func printTree(_ view: UIView, prefix: String, isLast: Bool, depth: Int) {
            if depth > maxDepth { return }
            
            let branch = isLast ? "└─ " : "├─ "
            print("\(prefix)\(branch)\(describeView(view))")
            
            let nextPrefix = prefix + (isLast ? "   " : "│  ")
            let subviews = view.subviews
            for (index, subview) in subviews.enumerated() {
                let last = index == subviews.count - 1
                printTree(subview, prefix: nextPrefix, isLast: last, depth: depth + 1)
            }
        }
        
        // Print root without leading branch
        print(describeView(root))
        let subviews = root.subviews
        for (index, subview) in subviews.enumerated() {
            let last = index == subviews.count - 1
            printTree(subview, prefix: "", isLast: last, depth: 1)
        }
    }
    
    /// Prints a minimal combined tree that includes the `UIView` hierarchy
    /// plus any `accessibilityElements` children exposed by objects.
    /// Runs on the main thread for UIKit safety.
    ///
    /// Example output:
    /// ├─ UIView(frame: {{0, 0}, {390, 844}})
    /// │  ├─ UILabel(frame: {{16, 24}, {200, 20}}, ax=1, "Title")
    /// │  │  └─ (AX) label="Title", value="", traits=[staticText]
    /// │  └─ UIView(frame: {{0, 100}, {390, 44}})
    /// │     └─ (AX) label="Search", value="", traits=[searchField]
    ///
    /// - Parameters:
    ///   - root: The root view to start printing from.
    ///   - maxDepth: Optional maximum depth to traverse.
    public func printCombinedViewAndAccessibilityTree(from root: UIView, maxDepth: Int = 64) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.printCombinedViewAndAccessibilityTree(from: root, maxDepth: maxDepth)
            }
            return
        }
        
        func describeView(_ view: UIView) -> String {
            let typeName = String(describing: type(of: view))
            let frameStr = "frame: \(NSCoder.string(for: view.frame))"
            let isAX = view.isAccessibilityElement ? "1" : "0"
            let label = (view.accessibilityLabel?.isEmpty == false) ? ", \"\(view.accessibilityLabel!)\"" : ""
            return "\(typeName)(\(frameStr), ax=\(isAX)\(label))"
        }
        
        func readableTraits(_ traits: UIAccessibilityTraits) -> String {
            var parts: [String] = []
            if traits.contains(.button) { parts.append("button") }
            if traits.contains(.link) { parts.append("link") }
            if traits.contains(.image) { parts.append("image") }
            if traits.contains(.staticText) { parts.append("staticText") }
            if traits.contains(.keyboardKey) { parts.append("keyboardKey") }
            if traits.contains(.searchField) { parts.append("searchField") }
            if traits.contains(.header) { parts.append("header") }
            if traits.contains(.selected) { parts.append("selected") }
            if traits.contains(.playsSound) { parts.append("playsSound") }
            if traits.contains(.summaryElement) { parts.append("summary") }
            if traits.contains(.updatesFrequently) { parts.append("updatesFrequently") }
            if traits.contains(.startsMediaSession) { parts.append("startsMedia") }
            if traits.contains(.adjustable) { parts.append("adjustable") }
            if traits.contains(.allowsDirectInteraction) { parts.append("directInteraction") }
            if traits.contains(.notEnabled) { parts.append("disabled") }
            if traits.contains(.keyboardKey) { parts.append("keyboardKey") }
            return parts.isEmpty ? "" : parts.joined(separator: "|")
        }
        
        func describeAX(_ object: NSObject, relativeTo root: UIView) -> String {
            let label = object.accessibilityLabel ?? ""
            let value = object.accessibilityValue ?? ""
            let traits = readableTraits(object.accessibilityTraits)
            let frame = object is UIView ? (object as! UIView).frame : root.convert(object.accessibilityFrame, from: nil)
            let frameStr = NSCoder.string(for: frame)
            return "(AX) label=\"\(label)\", value=\"\(value)\", traits=[\(traits)], frame: \(frameStr)"
        }
        
        func childrenForObject(_ object: NSObject) -> [NSObject] {
            if let view = object as? UIView {
                var children: [NSObject] = []
                if let axChildren = view.accessibilityElements as? [NSObject], !axChildren.isEmpty {
                    children.append(contentsOf: axChildren)
                }
                children.append(contentsOf: view.subviews)
                return children
            } else if let axChildren = object.accessibilityElements as? [NSObject] {
                return axChildren
            } else {
                return []
            }
        }
        
        func printTree(_ object: NSObject, prefix: String, isLast: Bool, depth: Int) {
            if depth > maxDepth { return }
            
            let branch = isLast ? "└─ " : "├─ "
            if let view = object as? UIView {
                print("\(prefix)\(branch)\(describeView(view))")
            } else {
                print("\(prefix)\(branch)\(describeAX(object, relativeTo: root))")
            }
            
            let nextPrefix = prefix + (isLast ? "   " : "│  ")
            let children = childrenForObject(object)
            for (index, child) in children.enumerated() {
                let last = index == children.count - 1
                printTree(child, prefix: nextPrefix, isLast: last, depth: depth + 1)
            }
        }
        
        // Print root without leading branch
        print(describeView(root))
        let children = childrenForObject(root)
        for (index, child) in children.enumerated() {
            let last = index == children.count - 1
            printTree(child, prefix: "", isLast: last, depth: 1)
        }
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
