# Swift Usage

Starting from version 8.0, it is now possible to include Swift code in the project. All Swift files should be placed under the `/Sources/Swift` directory.

> In this document, `SentryPrivate` refers to the library written in Swift, while `Sentry` represents the framework written in Objective-C. The term `SentryPrivate` public API refers to the API that will be consumed by `Sentry` and is not intended for direct use by users.

When working with Swift, it's important to keep the following restrictions in mind:

1. All Swift code will be bundled within the `SentryPrivate` library, which `Sentry` depends on.
2. User-facing APIs cannot be written in Swift because their components will be accessed through imports from "SentryPrivate."
3. `SentryPrivate` does not have access to `Sentry` classes to avoid cyclic references. As a result, any code written in Objective-C is not accessible from the  Swift layer.
    - However, it is possible to create Dependency Injection (DI) APIs in Swift, allowing `Sentry` to inject its objects for use within `SentryPrivate`.
4. `SentryPrivate` public APIs (code consumed by `Sentry`) cannot utilize certain Objective-C incompatible features, including:
    - Generics
    - Non-@objc protocols and protocol extensions
    - Top-level functions and properties
    - Global variables
    - Structs
    - Swift-only enums
    - Swift-only optionals
    - Swift-only tuples

By keeping these considerations in mind, you can effectively work with Swift code within the project, ensuring compatibility with the `Sentry` framework and adhering to the necessary restrictions imposed by the language differences.
