@_implementationOnly import _SentryPrivate
import Darwin
import Foundation
import MachO
@_implementationOnly import Sentry._Hybrid

@objc
class LoadValidator: NSObject {
    // Any class should be fine
    static let targetClassName = "PrivateSentrySDKOnly"
    
    @objc
    class func validateSDKPresenceIn(_ image: SentryBinaryImageInfo) {
        DispatchQueue.global(qos: .background).async {
            let systemLibraryPath = "/usr/lib/"
#if targetEnvironment(simulator)
            let ignoredPath = "/Library/Developer/CoreSimulator/Profiles/Runtimes/"
#else
            let ignoredPath = "/System/Library/"
#endif
            let imageName = image.name
            guard !imageName.contains(ignoredPath) && !imageName.hasPrefix(systemLibraryPath) else {
                return
            }
            
            let loadValidatorAddress = self.getCurrentFrameworkTextPointer()
            let imageAddress = image.address
            let imageSize = image.size
            let loadValidatorAddressValue = UInt(bitPattern: loadValidatorAddress)
            let isCurrentImageContainingLoadValidator = (loadValidatorAddressValue >= imageAddress) && (loadValidatorAddressValue < (imageAddress + imageSize))

            var classCount: UInt32 = 0
            imageName.withCString { cImageName in
                if let classNames = objc_copyClassNamesForImage(cImageName, &classCount) {
                    for j in 0..<Int(classCount) {
                        let name = String(cString: classNames[j])
                        if name.contains(self.targetClassName) {
                            if name == self.targetClassName && isCurrentImageContainingLoadValidator {
                                // Skip our implementation of `PrivateSentrySDKOnly`
                                continue
                            }
                            var message = ["❌ Sentry SDK was loaded multiple times in the binary ❌"]
                            message.append("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.")
                            message.append("Ensure the SDK is linked only once, found classes in image paths: \(imageName)")
                            print(message.joined(separator: "\n"))
                            
                            break
                        }
                    }
                    free(classNames)
                }
            }
        }
    }
    
    /**
     * Returns a pointer to a function inside the __TEXT segment of the binary containing this class
     */
    class func getCurrentFrameworkTextPointer() -> UnsafeRawPointer {
        let cFunction: @convention(c) () -> Void = { }
        let c = unsafeBitCast(cFunction, to: UnsafeRawPointer.self)
        return c
    }
}
