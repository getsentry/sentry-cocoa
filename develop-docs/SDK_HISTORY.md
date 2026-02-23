# SDK History

Historical context and FAQ for the Sentry Cocoa SDK.

For architectural decisions with detailed trade-off analysis, see [DECISIONS.md](DECISIONS.md).

## Why is the profiling code written in C++?

Sentry [acquired Specto](https://blog.sentry.io/bringing-specto-into-the-sentry-family/) in November 2021 to bring continuous profiling to the platform. Specto's co-founders, Indragie Karunaratne and Jernej Strasner, were former Meta engineers experienced with C++. The profiling code was written in C++ because the team that built it had prior expertise in C++, not because of a specific technical requirement.
