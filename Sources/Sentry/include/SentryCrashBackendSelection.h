// Only trait-aware SwiftPM manifests set this marker. Xcode and the base manifest keep
// their existing backend selection without requiring a package trait.
// Mutual exclusion checks actual traits; backend presence checks effective SDK_V10, which
// is enabled by either the V10 trait or the SDK_V10=1 environment override:
//
// V9 trait | V10 trait | Effective SDK_V10 | Result
// absent   | absent    | absent           | Error: no backend
// enabled  | absent    | absent           | V9
// absent   | enabled   | enabled          | V10
// absent   | absent    | enabled          | V10 (environment override)
// enabled  | absent    | enabled          | V10 (environment override with V9 defaults)
// enabled  | enabled   | either           | Error: mutually exclusive traits
//
// Thus V9 && SDK_V10 is not a conflict: SDK_V10=1 swift build retains the default V9 trait.
#if SENTRY_SWIFTPM_BACKEND_TRAITS && SENTRY_SWIFTPM_V9 && SENTRY_SWIFTPM_V10
#    define SENTRY_SWIFTPM_INVALID_CRASH_BACKEND 1
#    error "Sentry crash backend traits V9 and V10 are mutually exclusive: enable only one."
#elif SENTRY_SWIFTPM_BACKEND_TRAITS && !SENTRY_SWIFTPM_V9 && !SDK_V10
#    define SENTRY_SWIFTPM_INVALID_CRASH_BACKEND 1
#    error "Sentry requires a crash backend: enable the V9 or V10 package trait."
#endif
