# Tests

For test guidelines please checkout the [Contributing Guidelines](../CONTRIBUTING.md).

# Integration tests

* [SessionGeneratorTests](./SentryTests/Integrations/SentrySessionGeneratorTests.swift) generates session data to validate release health.
* [External integration tests](../.github/workflows/integration-tests.yml) integrate the Sentry SDK via CocoaPods into some open source apps and run their tests.

# Performance benchmarking

* [Performance benchmarks](../Samples/iOS-Swift/iOS-SwiftUITests/SDKPerformanceBenchmarkTests.swift) calculates the overhead CPU usage of the Sentry profiler.
