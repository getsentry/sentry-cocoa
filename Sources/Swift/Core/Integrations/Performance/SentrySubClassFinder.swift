@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit

class SentrySubClassFinder: NSObject {
    private let dispatchQueue: SentryDispatchQueueWrapper
    private let objcRuntimeWrapper: SentryObjCRuntimeWrapper
    private let swizzleClassNameExcludes: Set<String>

    init(
        dispatchQueue: SentryDispatchQueueWrapper,
        objcRuntimeWrapper: SentryObjCRuntimeWrapper,
        swizzleClassNameExcludes: Set<String>
    ) {
        self.dispatchQueue = dispatchQueue
        self.objcRuntimeWrapper = objcRuntimeWrapper
        self.swizzleClassNameExcludes = swizzleClassNameExcludes
        super.init()
    }

    /// Fetch all subclasses of `UIViewController` from given objc Image on a background thread and then
    /// act on them on the main thread. As there is no straightforward way to get all sub-classes in
    /// Objective-C, the code first retrieves all classes from the Image, iterates over all classes, and
    /// checks for every class if the parentClass is a `UIViewController`. Cause loading all classes can
    /// take a few milliseconds, do this on a background thread.
    /// - Parameters:
    ///   - imageName: The objc Image (library) to get all subclasses for.
    ///   - block: The block to execute for each subclass. This block runs on the main thread.
    func actOnSubclassesOfViewController(inImage imageName: String, block: @escaping (AnyClass) -> Void) {
        dispatchQueue.dispatchAsync {
            SentrySDKLog.debug("ActOnSubclassesOfViewControllerInImage: \(imageName)")

            guard let viewControllerClass = UIViewController.self as AnyClass? else {
                SentrySDKLog.debug("UIViewController class not found.")
                return
            }

            guard let cImageName = imageName.cString(using: .utf8) else {
                return
            }

            var count: UInt32 = 0
            guard let classes = self.objcRuntimeWrapper.copyClassNamesForImage(cImageName, &count) else {
                return
            }

            SentrySDKLog.debug("Found \(count) number of classes in image: \(imageName).")

            // Storing the actual classes in an NSArray would call initializer of the class, which we
            // must avoid as we are on a background thread here and dealing with UIViewControllers,
            // which assume they are running on the main thread. Therefore, we store the class name
            // instead so we can search for the subclasses on a background thread. We can't use
            // NSObject:isSubclassOfClass as not all classes in the runtime in classes inherit from
            // NSObject and a call to isSubclassOfClass would call the initializer of the class, which
            // we can't allow because of the problem with UIViewControllers mentioned above.
            //
            // Turn out the approach to search all the view controllers inside the app binary image is
            // fast and we don't need to include this restriction that will cause confusion.
            // In a project with 1000 classes (a big project), it took only ~3ms to check all classes.
            var classesToSwizzle: [String] = []

            for i in 0..<Int(count) {
                let classNamePtr = classes[i]
                let className = String(cString: classNamePtr)

                let shouldExcludeClassFromSwizzling = SentrySwizzleClassNameExclude.shouldExcludeClass(
                    className: className,
                    swizzleClassNameExcludes: self.swizzleClassNameExcludes
                )

                // It is vital to avoid calling NSClassFromString for the excluded classes because we
                // had crashes for specific classes when calling NSClassFromString, such as
                // https://github.com/getsentry/sentry-cocoa/issues/3798.
                if shouldExcludeClassFromSwizzling {
                    continue
                }

                guard let cls = NSClassFromString(className) else { continue }
                if self.isClass(cls, subClassOf: viewControllerClass) {
                    classesToSwizzle.append(className)
                }
            }

            free(classes)

            self.dispatchQueue.dispatchAsyncOnMainQueueIfNotMainThread {
                for className in classesToSwizzle {
                    if let cls = NSClassFromString(className) {
                        block(cls)
                    }
                }

                SentrySDKLog.debug(
                    "The following UIViewControllers for image: \(imageName) will generate automatic transactions: \(classesToSwizzle.joined(separator: ", "))"
                )
            }
        }
    }

    private func isClass(_ childClass: AnyClass?, subClassOf parentClass: AnyClass) -> Bool {
        guard var currentClass = childClass, currentClass != parentClass else {
            return false
        }

        // Using a do while loop, like pointed out in Cocoa with Love
        // (https://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html)
        // can lead to EXC_I386_GPFLT which stands for General Protection Fault and means we
        // are doing something we shouldn't do. It's safer to use a regular while loop to check
        // if superClass is valid.
        while let superClass = class_getSuperclass(currentClass), superClass != parentClass {
            currentClass = superClass
        }

        return class_getSuperclass(currentClass) == parentClass
    }
}

#endif
