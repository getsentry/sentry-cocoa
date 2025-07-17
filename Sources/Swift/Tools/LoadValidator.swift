@_implementationOnly import _SentryPrivate
import Darwin
import Foundation
import MachO

@objc
@_spi(Private) public final class LoadValidator: NSObject {
    // Any class should be fine, ObjC classes are better
    static let targetClassName = NSStringFromClass(SentryDependencyContainerSwiftHelper.self)
    
    @objc
    @_spi(Private) public class func validateSDKPresenceIn(_ image: SentryBinaryImageInfo) {
        internalValidateSDKPresenceIn(image,
                                      objcRuntimeWrapper: SentryDefaultObjCRuntimeWrapper.sharedInstance(),
                                      dispatchQueueWrapper: SentryDispatchQueueWrapper())
    }
    
    class func internalValidateSDKPresenceIn(_ image: SentryBinaryImageInfo, objcRuntimeWrapper: SentryObjCRuntimeWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper, resultHandler: ((Bool) -> Void)? = nil) {
        let systemLibraryPath = "/usr/lib/"
#if targetEnvironment(simulator)
        let ignoredPath = "/Library/Developer/CoreSimulator/Profiles/Runtimes/"
#else
        let ignoredPath = "/System/Library/"
#endif
        let imageName = image.name
        guard !imageName.contains(ignoredPath) && !imageName.hasPrefix(systemLibraryPath) else {
            resultHandler?(false)
            return
        }
        dispatchQueueWrapper.dispatchAsync {
            var duplicateFound = false
            defer {
                resultHandler?(duplicateFound)
            }
            
            let loadValidatorAddress = self.getCurrentFrameworkTextPointer()
            let imageAddress = image.address
            let imageSize = image.size
            let loadValidatorAddressValue = UInt(bitPattern: loadValidatorAddress)
            let isCurrentImageContainingLoadValidator = (loadValidatorAddressValue >= imageAddress) && (loadValidatorAddressValue < (imageAddress + imageSize))

            var classCount: UInt32 = 0
            imageName.withCString { cImageName in
                if let classNames = objcRuntimeWrapper.copyClassNames(forImage: cImageName, amount: &classCount) {
                    defer {
                        free(classNames)
                    }
                    for j in 0..<Int(classCount) {
                        guard let className = classNames[j] else {
                            continue
                        }
                        let name = String(cString: UnsafeRawPointer(className).assumingMemoryBound(to: UInt8.self))
                        if name == self.targetClassName && isCurrentImageContainingLoadValidator {
                            // Skip the implementation of the class we are using as a proxy for being loaded that exists in the same binary that this instance of LoadValidator was loaded in
                            continue
                        }
                        if name.contains(self.targetClassName) {
                            var message = ["❌ Sentry SDK was loaded multiple times in the binary ❌"]
                            message.append("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.")
                            message.append("Ensure the SDK is linked only once, found classes in image paths: \(imageName)")
                            SentrySDKLog.warning(message.joined(separator: "\n"))
                            duplicateFound = true
                            
                            break
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Returns a pointer to a function inside the `__TEXT` segment of the binary containing this class
     */
    class func getCurrentFrameworkTextPointer() -> UnsafeRawPointer {
        let cFunction: @convention(c) () -> Void = { }
        let c = unsafeBitCast(cFunction, to: UnsafeRawPointer.self)
        return c
    }
}
