# Carthage Samples

This directory contains samples to validate installing the SDK via Carthage.

Carthage can resolve a dependency by downloading the source code into `Carthage/Checkouts` or downloading a pre-compiled framework. The library authors can either attach the pre-compiled framework to a GitHub release or use a [binary project specification][1] for binary-only frameworks that don't provide the source code.
Carthage encourages its users [to use XCFrameworks][2] since version 0.37.0, released in January 2021.

Given the above, there are three different ways of installing a dependency via Carthage:

1. pre-compiled XCFramework
2. pre-compiled framework (Dropped support for that in 8.0.0)
3. downloading the source code

Since Carthage only downloads the source code if no pre-compiled binaries are available and we upload these binaries for every release, we only have to validate the first way.

Take a look at [GitHub Actions](../../.github/workflows/build.yml) to see how the validation works.

[1]: https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#binary-project-specification
[2]: https://github.com/Carthage/Carthage#getting-started
