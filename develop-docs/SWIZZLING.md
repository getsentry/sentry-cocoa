# Adding a Typed Swizzle

Use the typed Swift swizzling API for new Swift-owned swizzles. Keep method-signature support reusable and feature behavior in the feature that owns it.

## 1. Identify the Objective-C Method

The **receiver** is the object receiving the Objective-C message. It is the instance available as
`self` inside the method and the first argument passed to a typed interceptor. For example, when
`task.resume()` is called, `task` is the receiver.

The receiver is not necessarily the same concept as `classToSwizzle`:

- `Receiver` is the instance type accepted by the interceptor.
- `classToSwizzle` is the runtime class whose method implementation is replaced.
- They are often the same type, but `classToSwizzle` may be a subclass when swizzling an inherited
  method.

Record:

- Receiver type
- Selector
- Return type
- Explicit argument types and order
- Whether arguments or the result can be `nil`
- Platforms where the method exists
- Whether the method is public or private

Prefer `#selector` for public methods. Use `NSSelectorFromString` only when the method cannot be referenced by Swift, such as a private selector.

```swift
let selector = #selector(URLSessionTask.resume)
let privateSelector = NSSelectorFromString("setState:")
```

## 2. Add a Method Descriptor

Add reusable method metadata to `Sources/Swift/Core/Swizzling/SentrySwizzleMethod.swift` or a focused extension such as `SentrySwizzleMethod+URLSessionTask.swift`.

The generic arguments describe the receiver, explicit arguments, and result:

```swift
SentrySwizzleMethod<Receiver, Arguments, Result>
```

Here, `Receiver` is the type of `self` for intercepted calls. The interceptor receives that object as
its first argument.

The Objective-C ABI also passes the receiver (`self`) and selector (`_cmd`) before the method's
explicit arguments:

```swift
extension SentrySwizzleMethod where Arguments == Void, Result == Void {
    static func noArgumentVoid(_ selector: Selector, receiver: Receiver.Type) -> Self {
        .init(
            selector: selector,
            receiver: receiver,
            signature: .init(
                returnType: .void,
                arguments: [.object, .selector]
            )
        )
    }
}
```

Bind the selector in the descriptor. A feature-specific descriptor must own the exact public
`#selector` or private `NSSelectorFromString` value it represents. Do not accept that selector again
at installation time.

If the method uses an unsupported ABI type, add the smallest required `ABIType` support and direct parser and matching tests. Do not represent an unsupported type as a compatible existing type.

Runtime encodings validate ABI categories, not complete Swift types. They cannot distinguish nominal
Objective-C object classes, object nullability, or the parameters and result inside a block encoding.
Selector binding prevents a descriptor from being paired with another same-shaped method, but tests
must still verify the descriptor's exact selector and the real framework method signature.

Add `- SeeAlso:` documentation when the descriptor represents a public Apple API. Do not link a private method as public API.

## 3. Add a Typed Swizzle Overload

Add the reusable block and IMP bridging to `SentryTypedSwizzle.swift` or a focused extension such as `SentryTypedSwizzle+URLSessionTask.swift`.

The overload must:

1. Call `validate` before installing the swizzle.
2. Return `false` when validation fails.
3. Build an Objective-C block with the exact method calling convention.
4. Cast the original IMP to the exact C calling convention.
5. Fetch the original IMP when the original closure is invoked, not when the swizzle is installed.
6. Pass the receiver (`self`) and selector (`_cmd`) as the first two arguments to the original IMP.
7. Log unexpected runtime values with `SentrySDKLog` instead of asserting.

```swift
guard validate(in: classToSwizzle, method: method) else {
    return false
}

return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
    method.selector,
    in: classToSwizzle,
    mode: mode,
    key: key.pointer
) { getOriginal in
    { receiver in // The object receiving the Objective-C message, equivalent to self.
        guard let receiver = receiver as? Receiver else {
            SentrySDKLog.error("Unexpected swizzle receiver")
            return
        }

        interceptor(receiver) {
            let original = unsafeBitCast(
                getOriginal(),
                to: (@convention(c) (AnyObject, Selector) -> Void).self
            )
            original(receiver, method.selector)
        }
    } as @convention(block) (AnyObject) -> Void
}
```

Keep these typed overloads independent of feature classes such as trackers and integrations.

## 4. Install the Swizzle in the Owning Feature

The feature owns:

- Stable keys
- Choosing a feature-specific descriptor whose selector is already bound
- Class discovery
- Tracker or integration callbacks
- Argument or result transformation
- Platform guards

Use a process-lifetime key for each distinct swizzle. Do not create the key inside an installation method.

```swift
private enum FeatureSwizzleKeys {
    static let resume = SentryTypedSwizzle.Key()
}

SentryTypedSwizzle.instanceMethod(
    in: URLSessionTask.self,
    method: .urlSessionTaskResume(URLSessionTask.self),
    mode: .oncePerClassAndSuperclasses,
    key: FeatureSwizzleKeys.resume
) { task, original in
    tracker.didResume(task)
    original()
}
```

Choose the mode deliberately:

| Mode                           | Use                                                                       |
| ------------------------------ | ------------------------------------------------------------------------- |
| `.always`                      | Every installation must add another interceptor                           |
| `.oncePerClass`                | A key may install once on each class                                      |
| `.oncePerClassAndSuperclasses` | A key must not install when the class or a superclass is already swizzled |

Preserve the existing order between feature callbacks and the original implementation during migrations.

## 5. Add Tests

Keep tests separated by responsibility:

- `SentrySwizzleMethodTests.swift`: ABI parsing and generic signature matching
- `SentrySwizzleMethod<Feature>Tests.swift`: feature-specific descriptors and real runtime signatures
- `SentryTypedSwizzleTests.swift`: installation, forwarding, original calls, inheritance, keys, and modes
- Owning feature tests: feature behavior and integration lifecycle

At minimum, test:

- Matching runtime signature
- Missing selector
- Receiver type mismatch, including inherited-method cases
- Return type mismatch
- Argument count, type, and position mismatch
- Nil and non-nil optional blocks
- Argument replacement
- Result forwarding
- Inherited original implementation
- Repeated installation for the selected mode
- Different keys
- Multiple interceptor chaining when supported
- Real framework methods on every supported platform

For a migration, run the existing integration or end-to-end tests that exercised the previous swizzle implementation.

## Review Checklist

- [ ] Descriptor binds the exact selector it represents
- [ ] Descriptor matches every runtime-verifiable Objective-C ABI category
- [ ] Nominal object, nullability, and block-signature limits are covered by focused tests
- [ ] Typed overload contains no feature-specific dependency
- [ ] Feature owns stable keys and orchestration
- [ ] Original IMP is fetched dynamically
- [ ] Callback and original invocation order is intentional
- [ ] Invalid signatures log and skip installation
- [ ] No assertion or trap was added to a host-app code path
- [ ] Descriptor, adapter, and feature behavior are tested
- [ ] Real framework signature is tested when available
- [ ] All affected platforms build

## FAQ

### How does our swizzling relate to NSHipster's Method Swizzling article?

[Method Swizzling](https://nshipster.com/method-swizzling/) is the article people point to when discussing this SDK's swizzling. It was not a reference for our implementation — `SentrySwizzle` is a fork of RSSwizzle — and it targets an app swizzling its own classes, while we are a library swizzling Apple's classes in someone else's process. We follow several of its principles, but not all.

What we do follow:

- **Always invoke the original.** Enforced rather than conventional: test builds throw `SwizzlingError` when a replacement returns without calling it.
- **Swizzle exactly once.** Through `SentrySwizzleMode` and a stable key rather than `dispatch_once`, because the same swizzle is installed from several call sites for different classes.
- **Avoid collisions.** We go further and add no prefixed selector at all: we replace the IMP and resolve the original at call time (`SentrySwizzle.m`), so a third party swizzling the same selector after us is still reached.

Where we differ:

- **No swizzling in `+load`.** It runs before `main()`, so `Options` does not exist yet and `enableSwizzling` could not be honored, which users disable deliberately. Swizzling is also configured, not just switched on: `swizzleClassNameExcludes`, `inAppIncludes`, and per-feature gates all live in `Options`. We do use `+load` for non-swizzling early init, see [`OBJC-LOAD-AND-LINKING.md`](OBJC-LOAD-AND-LINKING.md).
- **Adding a method is a hazard, not a detail.** `class_replaceMethod` adds the method when the class does not implement it, which is harmless for your own classes but not for framework ones. Adding `loadView` stops nib loading, so `SentryUIViewControllerSwizzlingHelper` compares the IMP against the superclass and skips when they match. Adding an initializer broke Swift convenience initializers (GH-1355), removed in GH-1361, and swizzling view controllers off the main thread crashed (GH-1366).
