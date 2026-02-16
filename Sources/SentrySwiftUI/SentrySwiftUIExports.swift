// Re-export Sentry's SwiftUI types so that `import SentrySwiftUI` provides the same API
// as `import Sentry`. No duplicate declarations - avoids ambiguity when both are imported.
@_exported import Sentry
