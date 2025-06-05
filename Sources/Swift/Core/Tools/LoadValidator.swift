import Foundation
import MachO

@objc
class LoadValidator: NSObject {
    // Any class should be fine
    static let targetClassName = "PrivateSentrySDKOnly"
    
    @objc
    class func validateLoadedOnce() {
        let imageCount = _dyld_image_count()
        
        var imagesWhereSentryIsFound: [String] = [String]()
        
        // Iterate over all images to make sure none of them contains a Sentry implementation twice
        for i in 0..<imageCount {
            guard let cImageName = _dyld_get_image_name(i) else { continue }
            
            // Skip Apple Frameworks
            let imagePath = String(cString: cImageName)
            
            let systemLibraryPath = "/usr/lib/"
#if targetEnvironment(simulator)
            let ignoredPath = "/Library/Developer/CoreSimulator/Profiles/Runtimes/"
#else
            let ignoredPath = "/System/Library/"
#endif
            if imagePath.contains(ignoredPath) || imagePath.hasPrefix(systemLibraryPath) {
                continue
            }
            
            var classCount: UInt32 = 0
            if let classNames = objc_copyClassNamesForImage(cImageName, &classCount) {
                for j in 0..<Int(classCount) {
                    let name = String(cString: classNames[j])
                    if name.contains(self.targetClassName) {
                        imagesWhereSentryIsFound.append(imagePath)
                        break
                    }
                }
                free(classNames)
            }
        }
        
        if imagesWhereSentryIsFound.count > 1 {
            var message = ["❌ Sentry SDK was loaded multiple times in the binary ❌"]
            message.append("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.")
            message.append("Ensure the SDK is linked only once")
            imagesWhereSentryIsFound.forEach { path in
                message.append("  - \(path)")
            }
            print(message.joined(separator: "\n"))
#if DEBUG
            // Raise a debugger breakpoint
            raise(SIGTRAP)
#endif
        }
    }
}
