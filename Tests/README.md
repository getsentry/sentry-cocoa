# Tests

For test guidelines please checkout the [Contributing Guidelines](../CONTRIBUTING.md).

# Integration tests

* [SessionGeneratorTests](./SentryTests/Integrations/SentrySessionGeneratorTests.swift) generates session data to validate release health.
* [External integration tests](../.github/workflows/integration-tests.yml) integrate the Sentry SDK via CocoaPods into some open source apps and run their tests.
