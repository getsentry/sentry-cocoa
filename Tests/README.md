# Tests

For test guidelines please checkout the [Contributing Guidelines](../CONTRIBUTING.md).

Integrations tests for generating and sending data to Sentry to test certain features:

* [SessionGeneratorTests](./SentryTests/Integrations/SentrySessionGeneratorTests.swift) generates session data to validate release health.
* [TransactionGeneratorTests](./SentryTests/Performance/TransactionGeneratorTests.swift) generates transactions.
