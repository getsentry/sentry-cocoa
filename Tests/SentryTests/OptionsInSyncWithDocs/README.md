# Options Documentation Sync Tests

Automated tests to ensure all public properties in `Options.swift` have public-facing user documentation. This helps us remember to document every new option we add for SDK users.

- Docs repo: [sentry-docs](https://github.com/getsentry/sentry-docs)
- Options page: [options.mdx](https://github.com/getsentry/sentry-docs/blob/master/docs/platforms/apple/common/configuration/options.mdx)

## How It Works

1. **Extract properties** from `Options.swift` using Objective-C runtime + Swift Mirror
2. **Fetch documentation** from the sentry-docs GitHub repo
3. **Compare** and fail if any options are missing documentation

## When Tests Fail

Either:

1. **Add documentation** in sentry-docs for the new option
2. **Add to `undocumentedOptions`** in `SentryOptionsDocumentationSyncTests.swift` if docs are pending
