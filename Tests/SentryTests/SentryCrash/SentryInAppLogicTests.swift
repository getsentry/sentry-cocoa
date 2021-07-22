import XCTest

class SentryInAppLogicTests: XCTestCase {
    
    private class Fixture {
        
        func getSut(inAppIncludes: [String] = [], inAppExcludes: [String] = [] ) -> SentryInAppLogic {
            
            return SentryInAppLogic(
                inAppIncludes: inAppIncludes,
                inAppExcludes: inAppExcludes
            )
        }
    }
    
    private let fixture = Fixture()
    
    func testInApp_WithoutIncludesOrExcludes() {
        let sut = fixture.getSut()
        XCTAssertFalse(sut.is(inApp: "a/Bundle/Application/a"))
        XCTAssertFalse(sut.is(inApp: "a.app/"))
    }
    
    func testInApp_WithNil_ReturnsFalse() {
        XCTAssertFalse(fixture.getSut().is(inApp: nil))
    }
    
    func testInAppInclude_WithSpecifiedFramework() {
        XCTAssertTrue(
            fixture.getSut(inAppIncludes: ["PrivateFrameworks", "UIKitCore"])
                .is(inApp: "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore")
        )
    }
    
    func testInAppInclude_WithOnlyOneCharLowecase() {
        XCTAssertTrue(
            fixture.getSut(inAppIncludes: ["u"])
                .is(inApp: "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore")
        )
    }
  
    func testInAppInclude_WithWrongPrefix() {
        XCTAssertFalse(
            fixture.getSut(inAppIncludes: ["I"])
                .is(inApp: "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore")
        )
        XCTAssertFalse(fixture.getSut(inAppIncludes: ["/System", "UIKitCora"]).is(inApp: "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"))
    }
    
    func testInAppExclude_WithSpecifiedFramework() {
        XCTAssertFalse(
            fixture.getSut(inAppExcludes: ["iOS-Swift"])
                .is(inApp: "/private/var/containers/Bundle/Application/D987FC7A-629E-41DD-A043-5097EB29E2F4/iOS-Swift.app/iOS-Swift")
        )
    }
    
    func testInAppExclude_WithLowercasePrefix() {
        XCTAssertFalse(
            fixture.getSut(inAppExcludes: ["i"])
                .is(inApp: "/private/var/containers/Bundle/Application/D987FC7A-629E-41DD-A043-5097EB29E2F4/iOS-Swift.app/iOS-Swift")
        )
    }
    
    func testInAppIncludeTakesPrecedence() {
        XCTAssertTrue(
            fixture.getSut(inAppIncludes: ["libdyld.dylib"], inAppExcludes: ["libdyld.dylib"])
                .is(inApp: "/usr/lib/system/libdyld.dylib")
        )
    }
    
    func testInApp_WithNotMatchingIncludeButMatchingExclude() {
        XCTAssertFalse(
            fixture.getSut(inAppIncludes: ["iOS-Swifta"], inAppExcludes: ["iOS-Swift"])
                .is(inApp: "/private/var/containers/Bundle/Application/D987FC7A-629E-41DD-A043-5097EB29E2F4/iOS-Swift.app/iOS-Swift")
        )
    }
    
    func testXcodeLibraries_AreNotInApp() {
        XCTAssertFalse(fixture.getSut().is(inApp: "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"))
        
        // If someone has multiple Xcode installations
        XCTAssertFalse(fixture.getSut().is(inApp: "/Applications/Xcode 11.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"))
        
        // If someone installed Xcode in a different location that Applications
        XCTAssertFalse(fixture.getSut().is(inApp: "/Users/sentry/Downloads/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"))
    }
    
    func testFlutterOniPhone() {
        let images = Images(
            bundleExecutable: "/private/var/containers/Bundle/Application/0024E236-61B3-48D4-A9D3-209E4A7B54F3/Runner.app/Runner",
            privateFrameworks: [],
            publicFrameworks: [
                "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
                "/usr/lib/system/libdyld.dylib"
            ],
            privateSupportingFrameworks: [
                "/private/var/containers/Bundle/Application/0024E236-61B3-48D4-A9D3-209E4A7B54F3/Runner.app/Frameworks/Flutter.framework/Flutter",
                "/private/var/containers/Bundle/Application/0024E236-61B3-48D4-A9D3-209E4A7B54F3/Runner.app/Frameworks/Sentry.framework/Sentry"
            ])
        testWithImages(images: images, inAppIncludes: ["Runner"])
    }

    func testiOSOniPhone() {
        let images = Images(
            bundleExecutable: "/private/var/containers/Bundle/Application/B84AF2AB-BD6A-4D3F-9FC3-8430C4D9027E/iOS-Swift.app/iOS-Swift",
            privateFrameworks: [],
            publicFrameworks: [
                "/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore",
                "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
            ],
            privateSupportingFrameworks: [
                "/private/var/containers/Bundle/Application/03D20FB6-852C-4DD3-B69C-3231FB41C2B1/iOS-Swift.app/Frameworks/Sentry.framework/Sentry"
            ])
        testWithImages(images: images, inAppIncludes: ["iOS-Swift"])

    }
    
    func testiOSOnSimulator() {
        let images = Images(
            bundleExecutable: "/private/var/containers/Bundle/Application/03D20FB6-852C-4DD3-B69C-3231FB41C2B1/iOS-Swift.app/iOS-Swift",
            privateFrameworks: [],
            publicFrameworks: [
                "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation",
                "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore",
                "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/AccessibilityBundles/UIKit.axbundle/UIKit",
                "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices"
            ],
            privateSupportingFrameworks: [
                "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug-iphonesimulator/Sentry.framework/Sentry"
            ]
            )
        testWithImages(images: images, inAppIncludes: ["iOS-Swift"])
    }
    
    func testmacOS() {
        let images = Images(
            bundleExecutable: "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug/macOS-Swift.app/Contents/MacOS/macOS-Swift",
            privateFrameworks: [
                "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug/macOS-Swift.app/Contents/Frameworks/BusinessLogic.framework/Versions/A/BusinessLogic"
            ],
            publicFrameworks: [
                "/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit"
            ],
            privateSupportingFrameworks: [
                "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug/macOS-Swift.app/Contents/Frameworks/Sentry.framework/Versions/A/Sentry"
            ])
        
        testWithImages(images: images, inAppIncludes: ["macOS-Swift", "BusinessLogic"])
    }
    
    func testTvOSSimulator() {
        let images = Images(
            bundleExecutable: "Users/sentry/Library/Developer/CoreSimulator/Devices/6BC4053A-A44A-4E8A-8FFE-3412B0B057E4/data/Containers/Bundle/Application/FF6C4ED8-0B22-4E65-907A-68DCA4004A85/tvOS-Swift.app/tvOS-Swift",
            privateFrameworks: [],
            publicFrameworks:
                ["/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/tvOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore",
                 "/Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/tvOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/SwiftUI.framework/SwiftUI"],
            privateSupportingFrameworks: [
                "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug-appletvsimulator/Sentry.framework/Sentry"
            ])
        
        testWithImages(images: images, inAppIncludes: ["tvOS-Swift"])
    }
    
    func testWatchSimulator() {
        let images = Images(
            bundleExecutable: "/Users/sentry/Library/Developer/CoreSimulator/Devices/00266A97-0B09-4431-A52A-244DC348B1A4/data/Containers/Bundle/Application/EAD802DC-42A5-4C65-A8E1-8D8E528F96FE/watchOS-Swift WatchKit App.app/PlugIns/watchOS-Swift WatchKit Extension.appex/watchOS-Swift WatchKit Extension",
            privateFrameworks: [],
            publicFrameworks:
                ["/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/watchOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/SwiftUI.framework/SwiftUI",
                 "/Applications/Xcode.app/Contents/Developer/Platforms/WatchOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/watchOS.simruntime/Contents/Resources/RuntimeRoot/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore"],
            privateSupportingFrameworks: [
                "/Users/sentry/Library/Developer/Xcode/DerivedData/Sentry-gcimrafeikdpcwaanncxmwrieqhi/Build/Products/Debug-watchsimulator/Sentry.framework/Sentry"
            ])
        
        testWithImages(images: images, inAppIncludes: ["watchOS-Swift WatchKit Extension"])
    }
    
    func testWithImages(images: Images, inAppIncludes: [String], inAppExcludes: [String] = []) {
        let sut = fixture.getSut(inAppIncludes: inAppIncludes, inAppExcludes: inAppExcludes)
        XCTAssertTrue(sut.is(inApp: images.bundleExecutable))
        images.privateFrameworks.forEach {
            XCTAssertTrue(sut.is(inApp: $0))
        }
        images.publicFrameworks.forEach {
            XCTAssertFalse(sut.is(inApp: $0))
        }
        images.privateSupportingFrameworks.forEach {
            XCTAssertFalse(sut.is(inApp: $0))
        }
    }
    
    struct Images {
        let bundleExecutable: String
        /**
         Private frameworks embedded in the application bundle. These frameworks are embedded, but are part of the app and should me marked as inApp.
         */
        let privateFrameworks: [String]
        /**
         System frameworks and other public frameworks, located at /Library/Frameworks or ~/Library/Frameworks.
         */
        let publicFrameworks: [String]
        /**
         Private frameworks embedded in the application bundle. These frameworks support the app, but shouldn't be marked as inApp.
         */
        let privateSupportingFrameworks: [String]
    }
}
