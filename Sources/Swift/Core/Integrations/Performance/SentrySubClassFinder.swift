@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
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

            // Get the image's classes from its objc class list. This gives us the classes without
            // realizing them. We must not use NSClassFromString to find the subclasses, because it
            // realizes the class, and realizing a class whose Swift metadata references an
            // `@available`-gated newer-framework type crashes on older OS versions
            // (https://github.com/getsentry/sentry-cocoa/issues/8152,
            // https://github.com/swiftlang/swift/issues/72657). Walking the superclass chain with
            // `class_getSuperclass` below doesn't realize any class, so it can't trigger that crash.
            let classes = self.objcRuntimeWrapper.classes(forImage: cImageName)

            SentrySDKLog.debug("Found \(classes.count) number of classes in image: \(imageName).")

            // We inspect the classes on this background thread but only with `class_getSuperclass`
            // (in `isClass`) and `class_getName`. Neither sends an Objective-C message to the class,
            // so neither triggers its `+initialize`, which only runs on the first message send. This
            // matters because UIViewControllers assume they run on the main thread, so we must not
            // trigger their `+initialize` here. Storing the unrealized class pointers doesn't message
            // them either; the swizzling block on the main thread sends the first message, where
            // that is safe. We must not round-trip through NSClassFromString on the main thread
            // either: it realizes the class, and realizing a class whose Swift metadata references
            // an `@available`-gated newer-framework type crashes on older OS versions
            // (https://github.com/getsentry/sentry-cocoa/issues/8152,
            // https://github.com/swiftlang/swift/issues/72657) — the same reason we read the class
            // list from the image instead (see above). It could also resolve a same-named class
            // from a different image.
            var classesToSwizzle: [AnyClass] = []
            for cls in classes {
                guard self.isClass(cls, subClassOf: viewControllerClass) else {
                    continue
                }

                let className = String(cString: class_getName(cls))

                // It is vital to avoid swizzling the excluded classes because we had crashes for
                // specific classes, such as https://github.com/getsentry/sentry-cocoa/issues/3798.
                let shouldExcludeClassFromSwizzling = SentrySwizzleClassNameExclude.shouldExcludeClass(
                    className: className,
                    swizzleClassNameExcludes: self.swizzleClassNameExcludes
                )
                if shouldExcludeClassFromSwizzling {
                    continue
                }

                classesToSwizzle.append(cls)
            }

            self.dispatchQueue.dispatchAsyncOnMainQueueIfNotMainThread {
                for cls in classesToSwizzle {
                    block(cls)
                }

                SentrySDKLog.debug(
                    "The following UIViewControllers for image: \(imageName) will generate automatic transactions: \(classesToSwizzle.map { String(cString: class_getName($0)) }.joined(separator: ", "))"
                )
            }
        }
    }

    private func isClass(_ childClass: AnyClass?, subClassOf parentClass: AnyClass) -> Bool {
        guard childClass != nil, childClass != parentClass else {
            return false
        }

        var currentClass: AnyClass? = childClass

        // Using a do while loop, like pointed out in Cocoa with Love
        // (https://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html)
        // can lead to EXC_I386_GPFLT which stands for General Protection Fault and means we
        // are doing something we shouldn't do. It's safer to use a regular while loop to check
        // if superClass is valid.
        while currentClass != nil, currentClass != parentClass {
            currentClass = class_getSuperclass(currentClass)
        }

        return currentClass != nil
    }
}

#endif
