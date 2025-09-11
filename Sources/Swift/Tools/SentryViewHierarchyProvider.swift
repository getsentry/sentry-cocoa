#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

@_implementationOnly import _SentryPrivate
import UIKit

// C function pointer type from SentryCrashJSON
// typedef int (*SentryCrashJSONAddDataFunc)(const char *data, int length, void *userData)
typealias SentryCrashJSONAddDataFunc = @convention(c) (
    UnsafePointer<CChar>?, Int32, UnsafeMutableRawPointer?
) -> Int32

let writeJSONDataToFile: SentryCrashJSONAddDataFunc = { data, length, userData in
    guard let userData = userData else {
        return Int32(SentryCrashJSON_ERROR_CANNOT_ADD_DATA)
    }

    let fd = userData.assumingMemoryBound(to: Int32.self).pointee
    let success = sentrycrashfu_writeBytesToFD(fd, data, length)
    return success ? Int32(SentryCrashJSON_OK) : Int32(SentryCrashJSON_ERROR_CANNOT_ADD_DATA)
}

let writeJSONDataToMemory: SentryCrashJSONAddDataFunc = { data, length, userData in
    guard let userData = userData else {
        return Int32(SentryCrashJSON_ERROR_CANNOT_ADD_DATA)
    }
    let memory = Unmanaged<NSMutableData>.fromOpaque(userData).takeUnretainedValue()

    if let data = data {
        memory.append(data, length: Int(length))
    }

    return Int32(SentryCrashJSON_OK)
}

@discardableResult
func tryJson(_ result: Int32) -> Int32 {
    if result != SentryCrashJSON_OK {
        return result
    }
    return result
}

@_spi(Private) @objc public final class SentryViewHierarchyProvider: NSObject {
    @objc public init(dispatchQueueWrapper: SentryDispatchQueueWrapper, sentryUIApplication: SentryApplication) {
        self.reportAccessibilityIdentifier = true
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.sentryUIApplication = sentryUIApplication
    }
    
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let sentryUIApplication: SentryApplication
    
    /**
     * Whether we should add `accessibilityIdentifier` to the view hierarchy.
     */
    @objc public var reportAccessibilityIdentifier: Bool
    
    /**
     Get the view hierarchy in a json format.
     Always runs in the main thread.
     */
    @objc public func appViewHierarchyFromMainThread() -> Data? {
        var result: Data?

        let fetchViewHierarchy = {
            result = self.appViewHierarchy()
        }

        SentrySDKLog.info("Starting to fetch the view hierarchy from the main thread.")

        dispatchQueueWrapper.dispatchSyncOnMainQueue(block: fetchViewHierarchy)

        SentrySDKLog.info("Finished fetching the view hierarchy from the main thread.")

        return result
    }
    
    /**
     Get the view hierarchy in a json format.
     */
    @objc public func appViewHierarchy() -> Data? {
        let result = NSMutableData()
        let windows = self.sentryUIApplication.getWindows()

        let userData = Unmanaged.passUnretained(result).toOpaque()
        guard self.processViewHierarchy(
            windows: windows ?? [],
            addFunction: writeJSONDataToMemory,
            userData: userData
        ) else {
            return nil
        }

        return result as Data
    }
    
    /**
     * Save the current app view hierarchy in the given file path.
     *
     * @param filePath The full path where the view hierarchy should be saved.
     */
    @discardableResult @objc(saveViewHierarchy:) public func saveViewHierarchy(filePath: String) -> Bool {
        let windows = sentryUIApplication.getWindows()

        // let path = filePath.utf8CString
        var fd = open(filePath, O_RDWR | O_CREAT | O_TRUNC, 0_644)
        if fd < 0 {
            SentrySDKLog.debug("Could not open file \(filePath) for writing: \(String(cString: strerror(errno)))")
            return false
        }

        let result = self.processViewHierarchy(windows: windows ?? [], addFunction: writeJSONDataToFile, userData: &fd)

        close(fd)
        return result
    }
    
    func processViewHierarchy(windows: [UIView], addFunction: SentryCrashJSONAddDataFunc, userData: UnsafeMutableRawPointer?) -> Bool {
        // Declare the JSON context
        var jsonContext = SentryCrashJSONEncodeContext()

        // Begin encoding
        sentrycrashjson_beginEncode(&jsonContext, false, addFunction, userData)

        print("SENTRY_LOG_DEBUG: Processing view hierarchy.")

        // Equivalent to the ObjC block
        let serializeJson: () -> Int32 = {
            var result: Int32 = 0
            do {
                tryJson(sentrycrashjson_beginObject(&jsonContext, nil))
                tryJson(sentrycrashjson_addStringElement(
                    &jsonContext, "rendering_system", "UIKIT", SentryCrashJSON_SIZE_AUTOMATIC))
                tryJson(sentrycrashjson_beginArray(&jsonContext, "windows"))

                for window in windows {
                    tryJson(self.viewHierarchy(from: window, into: &jsonContext))
                }

                tryJson(sentrycrashjson_endContainer(&jsonContext))

                result = sentrycrashjson_endEncode(&jsonContext)
            }
            return result
        }

        let result = serializeJson()
        if result != SentryCrashJSON_OK {
            if let cStr = sentrycrashjson_stringForError(result) {
                let errStr = String(cString: cStr)
                print("SENTRY_LOG_DEBUG: Could not create view hierarchy json: \(errStr)")
            }
            return false
        }
        return true
    }
    
    func viewHierarchy(
        from view: UIView,
        into context: UnsafeMutablePointer<SentryCrashJSONEncodeContext>
    ) -> Int32 {
        print("SENTRY_LOG_DEBUG: Processing view hierarchy of view: \(view)")

        // Begin object
        tryJson(sentrycrashjson_beginObject(context, nil))

        // View type
        let className = SwiftDescriptor.getObjectClassName(view)
        className.withCString { cstr in
            _ = tryJson(sentrycrashjson_addStringElement(
                context, "type", cstr, SentryCrashJSON_SIZE_AUTOMATIC))
        }

        // Accessibility identifier (optional)
        if reportAccessibilityIdentifier,
           let identifier = view.accessibilityIdentifier,
           !identifier.isEmpty {
            identifier.withCString { cstr in
                _ = tryJson(sentrycrashjson_addStringElement(
                    context, "identifier", cstr, SentryCrashJSON_SIZE_AUTOMATIC))
            }
        }

        // Frame and alpha
        tryJson(sentrycrashjson_addFloatingPointElement(context, "width", Double(view.frame.size.width)))
        tryJson(sentrycrashjson_addFloatingPointElement(context, "height", Double(view.frame.size.height)))
        tryJson(sentrycrashjson_addFloatingPointElement(context, "x", Double(view.frame.origin.x)))
        tryJson(sentrycrashjson_addFloatingPointElement(context, "y", Double(view.frame.origin.y)))
        tryJson(sentrycrashjson_addFloatingPointElement(context, "alpha", Double(view.alpha)))

        // Visibility
        tryJson(sentrycrashjson_addBooleanElement(context, "visible", !view.isHidden))

        // If the view belongs directly to a UIViewController
        if let vc = view.next as? UIViewController, vc.view === view {
            let vcClassName = SwiftDescriptor.getViewControllerClassName(vc)
            vcClassName.withCString { cstr in
                _ = tryJson(sentrycrashjson_addStringElement(
                    context, "view_controller", cstr, SentryCrashJSON_SIZE_AUTOMATIC))
            }
        }

        // Children
        tryJson(sentrycrashjson_beginArray(context, "children"))
        for child in view.subviews {
            tryJson(viewHierarchy(from: child, into: context))
        }
        tryJson(sentrycrashjson_endContainer(context)) // end children array
        tryJson(sentrycrashjson_endContainer(context)) // end object

        return 0
    }
}

#endif
