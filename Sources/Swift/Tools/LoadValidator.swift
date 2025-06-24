@_implementationOnly import _SentryPrivate
import Darwin
import Foundation
import MachO

@objc
class LoadValidator: NSObject {
    // Any class should be fine
    static let targetClassName = "PrivateSentrySDKOnly"
    
    @objc
    class func validateSDKPresenceIn(_ image: SentryBinaryImageInfo, objcRuntimeWrapper: SentryObjCRuntimeWrapper) {
        internalValidateSDKPresenceIn(image, objcRuntimeWrapper: objcRuntimeWrapper)
    }
    
    /**
     * This synchronous version is intended to be used in tests.
     * It uses a higher QoS and wait for the result
     */
    @discardableResult class func validateSDKPresenceInSync(_ image: SentryBinaryImageInfo, objcRuntimeWrapper: SentryObjCRuntimeWrapper) -> Bool {
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        internalValidateSDKPresenceIn(image, objcRuntimeWrapper: objcRuntimeWrapper, qos: .userInitiated) { duplicateFound in
            result = duplicateFound
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
    
    class private func internalValidateSDKPresenceIn(_ image: SentryBinaryImageInfo, objcRuntimeWrapper: SentryObjCRuntimeWrapper, qos: DispatchQoS.QoSClass = .background, resultHandler: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: qos).async {
            var duplicateFound = false
            defer {
                resultHandler?(duplicateFound)
            }
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
                if let classNames = objcRuntimeWrapper.copyClassNames(forImage: cImageName, amount: &classCount) {
                    for j in 0..<Int(classCount) {
                        guard let className = classNames[j] else {
                            continue
                        }
                        let name = String(cString: UnsafeRawPointer(className).assumingMemoryBound(to: UInt8.self))
                        if name.contains(self.targetClassName) {
                            if name == self.targetClassName && isCurrentImageContainingLoadValidator {
                                // Skip our implementation of `PrivateSentrySDKOnly`
                                continue
                            }
                            var message = ["❌ Sentry SDK was loaded multiple times in the binary ❌"]
                            message.append("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.")
                            message.append("Ensure the SDK is linked only once, found classes in image paths: \(imageName)")
                            SentryLog.warning(message.joined(separator: "\n"))
                            duplicateFound = true
                            
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
