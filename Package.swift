// swift-tools-version:6.0

// Package targets and build settings must stay in a single manifest.
// swiftlint:disable file_length

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#elseif canImport(MSVCRT)
import MSVCRT
#endif

import PackageDescription

func envFlag(_ name: String) -> Bool {
    getenv(name).map { String(cString: $0) == "1" } ?? false
}

let enableV10 = envFlag("SDK_V10")
// SwiftPM has no source include override; CI audits this complement against the Xcode allowlist.
let v10ExcludedSentryCrashToolSources = [
    "SentryCrash/Recording/Tools/SentryCrashCPU.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_arm.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_arm64.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_x86_32.c",
    "SentryCrash/Recording/Tools/SentryCrashCPU_x86_64.c",
    "SentryCrash/Recording/Tools/SentryCrashMachineContext.c",
    "SentryCrash/Recording/Tools/SentryCrashMemory.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_MachineContext.c",
    "SentryCrash/Recording/Tools/SentryCrashThread.c",
    "SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.c",
    "SentryCrash/Recording/Tools/SentryCrashDate.c",
    "SentryCrash/Recording/Tools/SentryCrashDebug.c",
    "SentryCrash/Recording/Tools/SentryCrashDynamicLinker.c",
    "SentryCrash/Recording/Tools/SentryCrashFileUtils.c",
    "SentryCrash/Recording/Tools/SentryCrashID.c",
    "SentryCrash/Recording/Tools/SentryCrashJSONCodec.c",
    "SentryCrash/Recording/Tools/SentryCrashJSONCodecObjC.m",
    "SentryCrash/Recording/Tools/SentryCrashMach-O.c",
    "SentryCrash/Recording/Tools/SentryCrashMach.c",
    "SentryCrash/Recording/Tools/SentryCrashNSErrorUtil.m",
    "SentryCrash/Recording/Tools/SentryCrashObjC.c",
    "SentryCrash/Recording/Tools/SentryCrashSignalInfo.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_Backtrace.c",
    "SentryCrash/Recording/Tools/SentryCrashStackCursor_SelfThread.m",
    "SentryCrash/Recording/Tools/SentryCrashString.c",
    "SentryCrash/Recording/Tools/SentryCrashSysCtl.c",
    "SentryCrash/Recording/Tools/SentryCrashUUIDConversion.c"
]
let v10SwiftSettings: [SwiftSetting] = enableV10
    ? [.define("SDK_V10"), .define("SENTRY_DISABLE_SENTRYCRASH_V10")]
    : []
let v10CSettings: [CSetting] = enableV10
    ? [.define("SDK_V10", to: "1"), .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1")]
    : []
let v10CxxSettings: [CXXSetting] = enableV10
    ? [.define("SDK_V10", to: "1"), .define("SENTRY_DISABLE_SENTRYCRASH_V10", to: "1")]
    : []

// Match the wrapper targets' compiler settings in Sentry.xcodeproj.
var objcCompatSwiftSettings: [SwiftSetting] = []
#if compiler(>=6.1)
objcCompatSwiftSettings.append(.enableUpcomingFeature("MemberImportVisibility"))
#endif

// Older Xcodes ignore approachable concurrency. Some individual features already exist in
// older compilers, so gate the group to avoid enabling a subset that the project does not.
#if compiler(>=6.2)
objcCompatSwiftSettings += [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]
#endif

var products: [Product] = [
    .library(name: "SentryDistribution", targets: ["SentryDistribution"])
]

if !enableV10 {
    // BEGIN:BINARY_PRODUCTS
    products += [
        .library(name: "Sentry", targets: ["Sentry", "SentryCppHelper"]),
        .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
        .library(name: "Sentry-Dynamic-WithARM64e", targets: ["Sentry-Dynamic-WithARM64e"]),
        .library(name: "Sentry-WithoutUIKitOrAppKit", targets: ["Sentry-WithoutUIKitOrAppKit", "SentryCppHelper"]),
        .library(name: "Sentry-WithoutUIKitOrAppKit-WithARM64e", targets: ["Sentry-WithoutUIKitOrAppKit-WithARM64e", "SentryCppHelper"]),
        .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI", "SentryCppHelper"]),
        .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"]),
        .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"])
    ]
    // END:BINARY_PRODUCTS
}

var targets: [Target] = [
    .target(name: "SentryDistribution", path: "Sources/SentryDistribution"),
    .testTarget(name: "SentryDistributionTests", dependencies: ["SentryDistribution"], path: "Sources/SentryDistributionTests")
]

if !enableV10 {
    // BEGIN:BINARY_TARGETS
    targets += [
        .binaryTarget(
            name: "Sentry",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry.xcframework.zip",
            checksum: "63fe5a7258097fded9ef485bbb1d8e80e1e91d419ee6d8a6ad405454b5b50fef" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry-Dynamic.xcframework.zip",
            checksum: "2922a9e7744679aa1964076ae6fb8726a23187f2dff999a17ce3959281db3d61" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "Sentry-Dynamic-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry-Dynamic-WithARM64e.xcframework.zip",
            checksum: "2aaaa95b5a476345205313a0eb4e01a7828d7196902864945cc453250ddd3d46" //Sentry-Dynamic-WithARM64e
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry-WithoutUIKitOrAppKit.xcframework.zip",
            checksum: "ae6585bbfc4d262702c2f725f524d4c542105054c3f4995677a1a30b651b27df" //Sentry-WithoutUIKitOrAppKit
        ),
        .binaryTarget(
            name: "Sentry-WithoutUIKitOrAppKit-WithARM64e",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/Sentry-WithoutUIKitOrAppKit-WithARM64e.xcframework.zip",
            checksum: "0017c1c0dbdbc763283ee6567bad961f6864a9c16d710252d54c6eaf4ec604e2" //Sentry-WithoutUIKitOrAppKit-WithARM64e
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "dfed1c41a2b91256e52c2b7cfcc3d3c911c6f4204a07426c3e3098b7990b045f" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.0/SentryObjC-Static.xcframework.zip",
            checksum: "b8107f3f60b635d6f38d8c7a51f8cc62a5753f9631ae36adc1b8299dd51b3800" //SentryObjC-Static
        ),
        .target(
            name: "SentrySwiftUI",
            dependencies: ["Sentry"],
            path: "Sources/SentrySwiftUI",
            exclude: ["module.modulemap"],
            linkerSettings: [
                .linkedFramework("Sentry")
            ]
        ),
        .target(
            name: "SentryCppHelper",
            path: "Sources/SentryCppHelper",
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ]
    // END:BINARY_TARGETS
}

// Targets required to support compile-from-source builds via SPM.
if enableV10 {
    products.append(.library(name: "Sentry", targets: ["SentryObjCInternal"]))
} else {
    products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
}
let sentrySwiftExcludes = enableV10 ? [
    "Integrations/SentryCrash",
    "SentryCrash/SentryCrashSwift.swift",
    "SentryCrash/SentryDefaultCrashReporter.swift"
] : []

let sentrySwiftTarget: Target = .target(
    name: "SentrySwift",
    dependencies: ["_SentryPrivate", "SentryHeaders"],
    path: "Sources/Swift",
    exclude: sentrySwiftExcludes,
    cSettings: v10CSettings,
    swiftSettings: v10SwiftSettings
)

if enableV10 {
    sentrySwiftTarget.dependencies += [
        .product(name: "Recording", package: "KSCrash"),
        .product(name: "RecordingCore", package: "KSCrash")
    ]
}

var sentryObjCInternalExcludes = [
    "Sentry/SentryDummyPublicEmptyClass.m",
    "Sentry/SentryDummyPrivateEmptyClass.m",
    "Swift",
    "SentrySwiftUI",
    "Resources",
    "Configuration",
    "SentryCppHelper",
    "SentryDistribution",
    "SentryDistributionTests",
    "SentryObjC",
    "SentryObjCCompat"
]

if enableV10 {
    sentryObjCInternalExcludes += v10ExcludedSentryCrashToolSources + [
        "Sentry/SentryCrashReportSink.m",
        "Sentry/SentryCrashScopeObserver.m",
        "SentryCrash/Installations",
        "SentryCrash/Reporting",
        "SentryCrash/Recording/Monitors",
        "SentryCrash/Recording/SentryCrash.m",
        "SentryCrash/Recording/SentryCrashBinaryImageCache.c",
        "SentryCrash/Recording/SentryCrashBinaryImageCacheState.h",
        "SentryCrash/Recording/SentryCrashC.c",
        "SentryCrash/Recording/SentryCrashCachedData.c",
        "SentryCrash/Recording/SentryCrashCachedData.h",
        "SentryCrash/Recording/SentryCrashDoctor.h",
        "SentryCrash/Recording/SentryCrashDoctor.m",
        "SentryCrash/Recording/SentryCrashReport.c",
        "SentryCrash/Recording/SentryCrashReport.h",
        "SentryCrash/Recording/SentryCrashReportFields.h",
        "SentryCrash/Recording/SentryCrashReportFixer.c",
        "SentryCrash/Recording/SentryCrashReportFixer.h",
        "SentryCrash/Recording/SentryCrashReportStore.c",
        "SentryCrash/Recording/SentryCrashReportStore.h",
        "SentryCrash/Recording/SentryCrashReportVersion.h",
        "SentryCrash/Recording/Tools/SentryCrashCxaThrowSwapper.h",
        "SentryCrash/Recording/Tools/SentryCrashSysCtl.h"
    ]
}

let sentryObjCInternalCSettings: [CSetting] = [
    .headerSearchPath("Sentry"),
    .headerSearchPath("SentryCrash/Recording"),
    .headerSearchPath("SentryCrash/Recording/Monitors"),
    .headerSearchPath("SentryCrash/Recording/Tools"),
    .headerSearchPath("SentryCrash/Installations"),
    .headerSearchPath("SentryCrash/Reporting/Filters"),
    .headerSearchPath("SentryCrash/Reporting/Filters/Tools")
] + v10CSettings

let sentryPrivateDependencies: [Target.Dependency] = if enableV10 {
    ["SentryHeaders", .product(name: "Recording", package: "KSCrash")]
} else {
    ["SentryHeaders"]
}

targets += [
    // At least one source file is required, therefore we use a dummy class to satisfy the SPM build system
    .target(
        name: "SentryHeaders",
        path: "Sources/Sentry",
        sources: ["SentryDummyPublicEmptyClass.m"],
        publicHeadersPath: "Public",
        cSettings: v10CSettings
    ),
    .target(
        name: "_SentryPrivate",
        dependencies: sentryPrivateDependencies,
        path: "Sources/Sentry",
        sources: ["SentryDummyPrivateEmptyClass.m"],
        publicHeadersPath: "include",
        cSettings: v10CSettings
    ),

    sentrySwiftTarget
]

var sentryObjCInternalDependencies: [Target.Dependency] = ["SentrySwift"]
if enableV10 {
    sentryObjCInternalDependencies.append(.product(name: "Recording", package: "KSCrash"))
}

targets += [
    // SentryObjCInternal compiles all ObjC/C sources from the repo. Named "Internal"
    // to reserve "SentryObjC" for a future public Objective-C wrapper around the SDK.
    .target(
        name: "SentryObjCInternal",
        dependencies: sentryObjCInternalDependencies,
        path: "Sources",
        exclude: sentryObjCInternalExcludes,
        cSettings: sentryObjCInternalCSettings)
]

// BEGIN:OBJC_WRAPPER
products.append(.library(name: "SentryObjC", targets: ["SentryObjC"]))
targets += [
    .target(
        name: "SentryObjCCompat",
        dependencies: ["SentryObjCInternal"],
        path: "Sources/SentryObjCCompat",
        cSettings: v10CSettings,
        swiftSettings: v10SwiftSettings + objcCompatSwiftSettings
    ),
    .target(
        name: "SentryObjC",
        dependencies: ["SentryObjCCompat"],
        path: "Sources/SentryObjC",
        publicHeadersPath: "Public",
        cSettings: [
            .headerSearchPath("Public")
        ] + v10CSettings
    )
]
// END:OBJC_WRAPPER

targets += [
    .target(
        name: "SentryTestUtilsObjC",
        dependencies: ["SentryObjCInternal", "SentrySwift", "_SentryPrivate", "SentryHeaders"],
        path: "SentryTestUtils/SourcesObjC",
        publicHeadersPath: "include",
        cSettings: v10CSettings
    ),
    .target(
        name: "SentryTestUtilsObjCpp",
        dependencies: ["SentryObjCInternal", "_SentryPrivate"],
        path: "SentryTestUtils/SourcesObjCpp",
        publicHeadersPath: ".",
        cSettings: v10CSettings,
        cxxSettings: v10CxxSettings,
        linkerSettings: [
            // The profiler mocks use C++ standard-library types such as std::vector.
            .linkedLibrary("c++")
        ]
    ),
    .target(
        name: "SentryTestUtils",
        dependencies: [
            "SentryObjCInternal",
            "SentrySwift",
            "_SentryPrivate",
            "SentryTestUtilsObjC",
            "SentryTestUtilsObjCpp"
        ],
        path: "SentryTestUtils/Sources",
        swiftSettings: v10SwiftSettings
    ),
    .testTarget(
        name: "SentryTestUtilsTests",
        dependencies: ["SentrySwift", "SentryTestUtils"],
        path: "SentryTestUtilsTests/Sources",
        swiftSettings: v10SwiftSettings
    ),
    .testTarget(
        name: "SentryObjCCompatTests",
        dependencies: ["SentryObjCCompat", "SentrySwift", "SentryTestUtils"],
        path: "Tests/SentryObjCCompatTests",
        swiftSettings: v10SwiftSettings + objcCompatSwiftSettings
    )
]

// Swift tests use directory discovery. A new Clang source must be assigned to one of
// these language-specific targets; the inventory audit detects omissions.
let sentryTestClangFiles = [
    "Categories/SentrySanitizerUtils+Tests.m",
    "Helper/ExceptionCatcher.m",
    "Helper/SentryAsyncSafeLog.m",
    "Helper/SentryDeviceTests.m",
    "Helper/SentryJSONStreamWriterTests.m",
    "Helper/SentryLogTestHelper.m",
    "Helper/SentryMigrateSessionInitTests.m",
    "Helper/SentrySerializationNilTests.m",
    "Helper/SentrySwizzleTests.m",
    "Helper/SentryTestObjCRuntimeWrapper.m",
    "Helper/SentryTimeTests.m",
    "Integrations/KSCrash/SentryCxaThrowCompatibilityTests.mm",
    "Integrations/Performance/IO/SentryFileIOTrackingIntegrationObjCTests.m",
    "Integrations/Performance/Network/URLSessionTaskMock.m",
    "Integrations/Performance/SentryInitializeForGettingSubclassesNotCalled.m",
    "Integrations/SentryCrash/SentryCrashScopeHelper.m",
    "Integrations/SentryCrash/SentryTestIntegration.m",
    "Integrations/SessionReplay/SentryFileIOTests.m",
    "Integrations/SessionReplay/SentryReplayOptionsObjcTests.m",
    "Integrations/SessionReplay/SentrySessionReplaySyncCTests.m",
    "MockUIScene.m",
    "Networking/NSData+Unzip.m",
    "Networking/SentryDispatchFactoryTests.m",
    "Networking/SentryDispatchQueueWrapperTests.m",
    "Networking/SentryDsnTests.m",
    "Protocol/SentryAppState+Equality.m",
    "Protocol/SentryAttachment+Equality.m",
    "Protocol/SentryMessage+Equality.m",
    "SentryCrash/Container+DeepSearch_Tests.m",
    "SentryCrash/FileBasedTestCase.m",
    "SentryCrash/RFC3339UTFString_Tests.m",
    "SentryCrash/SentryCrashBinaryImageCacheTestHelper.m",
    "SentryCrash/SentryCrashBinaryImageCacheTests.m",
    "SentryCrash/SentryCrashCPU_Tests.m",
    "SentryCrash/SentryCrashCachedData_Tests.m",
    "SentryCrash/SentryCrashCxaThrowSwapper_Tests.mm",
    "SentryCrash/SentryCrashDebug_Tests.m",
    "SentryCrash/SentryCrashDynamicLinkerTests.m",
    "SentryCrash/SentryCrashDynamicLinker_Tests.m",
    "SentryCrash/SentryCrashFileUtils_Tests.m",
    "SentryCrash/SentryCrashJSONCodec_Tests.m",
    "SentryCrash/SentryCrashMach-OTests.m",
    "SentryCrash/SentryCrashMach_Tests.m",
    "SentryCrash/SentryCrashMachineContextTests.m",
    "SentryCrash/SentryCrashMemory_Tests.m",
    "SentryCrash/SentryCrashMonitor_AppState_Tests.m",
    "SentryCrash/SentryCrashMonitor_CppException_Tests.mm",
    "SentryCrash/SentryCrashMonitor_NSException_StackCursor_Tests.m",
    "SentryCrash/SentryCrashMonitor_NSException_Tests.m",
    "SentryCrash/SentryCrashMonitor_Signal_Tests.m",
    "SentryCrash/SentryCrashMonitor_Tests.m",
    "SentryCrash/SentryCrashNSErrorUtilTests.m",
    "SentryCrash/SentryCrashObjC_Tests.m",
    "SentryCrash/SentryCrashReportFilter_Tests.m",
    "SentryCrash/SentryCrashReportFixer_Tests.m",
    "SentryCrash/SentryCrashReportStore_Tests.m",
    "SentryCrash/SentryCrashSignalInfo_Tests.m",
    "SentryCrash/SentryCrashString_Tests.m",
    "SentryCrash/SentryCrashSysCtl_Tests.m",
    "SentryCrash/SentryCrashTests.m",
    "SentryCrash/TestThread.m",
    "SentryCrash/XCTestCase+SentryCrash.m",
    "SentryCrashReportConverterTests.m",
    "SentryInterfacesTests.m",
    "SentryMsgPackSerializerTests.m",
    "SentryNSDataCompressionTests.m",
    "SentryOptionsTest.m",
    "SentryScope+Equality.m",
    "SentryScopeTests.m",
    "SentryTests.m",
    "Swift/Tools/SentryDictionaryDecoderObjCTests.m",
    "TestUtils/SentryBooleanSerialization.m",
    "TestUtils/SentryClassRegistrator.m",
    "TestUtils/SentryInvalidJSONString.m",
    "Transaction/SentryTracer+Test.m",
    "Transaction/TestSentrySpan.m"
]
let sentryTestObjCHelpers = [
    "Categories/SentrySanitizerUtils+Tests.m",
    "Helper/ExceptionCatcher.m",
    "Helper/SentryLogTestHelper.m",
    "Helper/SentryTestObjCRuntimeWrapper.m",
    "Integrations/Performance/Network/URLSessionTaskMock.m",
    "Integrations/Performance/SentryInitializeForGettingSubclassesNotCalled.m",
    "Integrations/SentryCrash/SentryCrashScopeHelper.m",
    "Integrations/SentryCrash/SentryTestIntegration.m",
    "MockUIScene.m",
    "Networking/NSData+Unzip.m",
    "Protocol/SentryAppState+Equality.m",
    "Protocol/SentryAttachment+Equality.m",
    "Protocol/SentryMessage+Equality.m",
    "SentryCrash/FileBasedTestCase.m",
    "SentryCrash/SentryCrashBinaryImageCacheTestHelper.m",
    "SentryCrash/TestThread.m",
    "SentryCrash/XCTestCase+SentryCrash.m",
    "SentryScope+Equality.m",
    "TestUtils/SentryBooleanSerialization.m",
    "TestUtils/SentryClassRegistrator.m",
    "TestUtils/SentryInvalidJSONString.m",
    "Transaction/SentryTracer+Test.m",
    "Transaction/TestSentrySpan.m"
]
let sentryTestSwiftHelpers = ["TestUtils/SentryDictionaryDecoderObjCHelper.swift", "TestUtils/SentryTestResources.swift", "Helper/UrlSessionDelegateSpy.swift"]
// Matches SentryTestsV10.xcconfig plus the V10 synchronized-group membership exceptions.
let sentryTestV10Exclusions: [String] = [
    "Integrations/Performance/SwizzlingCallTests.swift",
    "Integrations/Performance/UIViewController/SentryUIViewControllerPerformanceTrackerTests.swift",
    "Integrations/Performance/UIViewController/SentryUIViewControllerSwizzlingTests.swift",
    "Integrations/Performance/UIViewController/SentryVCTrackerLaunchProfilingTests.swift",
    "Integrations/SentryCrash/SentryCrashIntegrationTests.swift",
    "Integrations/SentryCrash/SentryCrashReportTests.swift",
    "Integrations/SentryCrash/SentryCrashScopeHelper.m",
    "Integrations/SentryCrash/SentryCrashScopeObserverTests.swift",
    "Integrations/SentryCrash/SentryTestIntegration.m",
    "Integrations/SentryCrash/SentryUncaughtNSExceptionsTests.swift",
    "Integrations/Session/SentrySessionGeneratorTests.swift",
    "Recording/SentryCrashCTests.swift",
    "SentryCrash/Container+DeepSearch_Tests.m",
    "SentryCrash/RFC3339UTFString_Tests.m",
    "SentryCrash/SentryCrashBinaryImageCacheTestHelper.m",
    "SentryCrash/SentryCrashBinaryImageCacheTests.m",
    "SentryCrash/SentryCrashCachedData_Tests.m",
    "SentryCrash/SentryCrashCxaThrowSwapper_Tests.mm",
    "SentryCrash/SentryCrashDebug_Tests.m",
    "SentryCrash/SentryCrashDoctorTests.swift",
    "SentryCrash/SentryCrashDynamicLinkerTests.m",
    "SentryCrash/SentryCrashDynamicLinker_Tests.m",
    "SentryCrash/SentryCrashFileUtils_Tests.m",
    "SentryCrash/SentryCrashInstallationReporterTests.swift",
    "SentryCrash/SentryCrashInstallationTests.swift",
    "SentryCrash/SentryCrashJSONCodec_Tests.m",
    "SentryCrash/SentryCrashMach-OTests.m",
    "SentryCrash/SentryCrashMach_Tests.m",
    "SentryCrash/SentryCrashMonitor_AppState_Tests.m",
    "SentryCrash/SentryCrashMonitor_CppException_Tests.mm",
    "SentryCrash/SentryCrashMonitor_NSException_StackCursor_Tests.m",
    "SentryCrash/SentryCrashMonitor_NSException_Tests.m",
    "SentryCrash/SentryCrashMonitor_Signal_Tests.m",
    "SentryCrash/SentryCrashMonitor_Tests.m",
    "SentryCrash/SentryCrashNSErrorUtilTests.m",
    "SentryCrash/SentryCrashObjC_Tests.m",
    "SentryCrash/SentryCrashReportFilter_Tests.m",
    "SentryCrash/SentryCrashReportFixer_Tests.m",
    "SentryCrash/SentryCrashReportSinkTests.swift",
    "SentryCrash/SentryCrashReportStore_Tests.m",
    "SentryCrash/SentryCrashSignalInfo_Tests.m",
    "SentryCrash/SentryCrashStackCursorSelfThreadTests.swift",
    "SentryCrash/SentryCrashString_Tests.m",
    "SentryCrash/SentryCrashSysCtl_Tests.m",
    "SentryCrash/SentryCrashTests.m",
    "SentryCrashExceptionApplicationTests.swift"
]
func sentryTestSources(_ files: [String]) -> [String] {
    files.filter { file in
        !enableV10 || !sentryTestV10Exclusions.contains(file)
    }.map { "SentryTests/" + $0 }
}
let sentryTestHeaderPaths = [
    "SentryTests", "SentryTests/Helper", "SentryTests/Networking", "SentryTests/Protocol",
    "SentryTests/SentryCrash", "SentryTests/TestUtils", "SentryTests/Transaction",
    "SentryTests/Integrations/Performance", "SentryTests/Integrations/Performance/Network",
    "SentryTests/Integrations/SentryCrash", "SentryTests/Categories",
    "../SentryTestUtils/Headers", "../Sources/Sentry", "../Sources/Sentry/include", "../Sources/SentryCrash/Recording",
    "../Sources/SentryCrash/Recording/Tools", "../Sources/SentryCrash/Recording/Monitors",
    "../Sources/SentryCrash/Reporting/Filters", "../Sources/SentryCrash/Reporting/Filters/Tools",
    "../Sources/SentryCrash/Installations"
]
let sentryTestCSettings = sentryTestHeaderPaths.map { CSetting.headerSearchPath($0) } + v10CSettings
let sentryTestCxxSettings = sentryTestHeaderPaths.map { CXXSetting.headerSearchPath($0) } + v10CxxSettings
let sentryTestDependencies: [Target.Dependency] = [
    "SentrySwift", "SentryObjCInternal", "_SentryPrivate", "SentryTestUtils",
    "SentryTestsObjCHelpers", "SentryTestsSwiftHelpers"
]
// Exclude neighboring suites rather than moving sources out of the synchronized Xcode group.
let sentryTestExcludes = [
    "AGENTS.md", "Configuration", "DuplicatedSDKTest", "Perf", "README.md", "SentryObjCCompatTests",
    "SentryObjCTests", "SentryProfilerTests", "ThreadInspectionHarness", "ThreadSanitizer.sup",
    "SentryTests/Info.plist", "SentryTests/SentryTests-Bridging-Header.h",
    "SentryTests/OptionsInSyncWithDocs/README.md"
]
targets += [
    .target(
        name: "SentryTestsObjCHelpers",
        dependencies: ["SentrySwift", "SentryObjCInternal", "_SentryPrivate", "SentryTestUtilsObjC", "SentryTestUtilsObjCpp", "SentryTestsSwiftHelpers"],
        path: "Tests",
        exclude: sentryTestExcludes,
        sources: sentryTestSources(sentryTestObjCHelpers) + ["SentryTestsSupport/SentryTestsBridge.m"],
        publicHeadersPath: "SentryTestsSupport/include",
        cSettings: sentryTestCSettings,
        linkerSettings: [.linkedLibrary("z")]
    ),
    .target(
        name: "SentryTestsSwiftHelpers",
        dependencies: ["SentrySwift"],
        path: "Tests",
        exclude: sentryTestExcludes,
        sources: sentryTestSources(sentryTestSwiftHelpers),
        resources: [.copy("Resources"), .copy("SentryTests/Helper/InfoPlist/TestInfoPlist.plist")],
        swiftSettings: v10SwiftSettings
    )
]
let sentrySwiftTestExcludedSources = sentryTestClangFiles + sentryTestSwiftHelpers + (enableV10 ? sentryTestV10Exclusions : [])
let sentrySwiftTestExcludes = sentryTestExcludes + ["SentryTestsSupport", "SentryTests/Helper/InfoPlist/TestInfoPlist.plist"] +
    Set(sentrySwiftTestExcludedSources).sorted().map { "SentryTests/" + $0 }
targets += [
    .testTarget(
        name: "SentryTests",
        dependencies: sentryTestDependencies + [.product(name: "SentryTestUtilsDynamic", package: "SentryTestUtilsDynamic")],
        path: "Tests",
        exclude: sentrySwiftTestExcludes,
        sources: ["SentryTests"],
        // SwiftPM does not define SWIFT_PACKAGE for Swift's Clang importer.
        cSettings: [.define("SWIFT_PACKAGE", to: "1")] + v10CSettings,
        swiftSettings: v10SwiftSettings + [.enableUpcomingFeature("BareSlashRegexLiterals")]
    )
]
targets += [
    .testTarget(
        name: "SentryTestsObjC",
        dependencies: sentryTestDependencies,
        path: "Tests",
        exclude: sentryTestExcludes,
        sources: sentryTestSources(sentryTestClangFiles.filter { !sentryTestObjCHelpers.contains($0) }),
        cSettings: sentryTestCSettings,
        cxxSettings: sentryTestCxxSettings,
        linkerSettings: [.linkedLibrary("c++")]
    )
]

var packageDependencies: [Package.Dependency] = enableV10 ? [.package(url: "https://github.com/getsentry/KSCrash.git", revision: "391bf0a9569b6c1aa9df30b3fa4bcabbc0a07e7a")] : []

packageDependencies.append(.package(path: "SentryTestUtilsDynamic"))

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
