# watchOS-Swift Sample

Run `make build-for-watchos` to build the Sentry.xcframework on which this
sample project depends on.


**Why XCFramework and not include a normal Framework as the other samples do it?**

With the current project setup we can't add the Sentry.framework, like we do for the other sample projects, to a watchOS project. If we try to add it 
we get the following error:

```
Building for watchOS Simulator, but the linked framework 'Sentry.framework' is building for iOS Simulator. You may need to configure 'Sentry.framework' to build for watchOS Simulator.
```

A solution would be to add Sentry via as a Swift Package, but this would
slow down the development cycle.

A [XCFramework](https://help.apple.com/xcode/mac/11.4/#/dev6f6ac218b) can be
used on multiple platforms. As of July 2020 we need to manually create
XCFrameworkes with [xcodebuild](https://help.apple.com/xcode/mac/11.4/#/dev544efab96) and therefore we can't link directly to a XCFramework so
Xcode builds it for us.