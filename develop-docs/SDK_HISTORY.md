# SDK History

Historical context and FAQ for the Sentry Cocoa SDK.

For architectural decisions with detailed trade-off analysis, see [DECISIONS.md](DECISIONS.md).

## Why is the profiling code written in C++?

Sentry [acquired Specto](https://blog.sentry.io/bringing-specto-into-the-sentry-family/) in November 2021 to bring continuous profiling to the platform. Specto's co-founders, Indragie Karunaratne and Jernej Strasner, were former Meta engineers experienced with C++. According to Indragie, the profiling logic—especially constructing stack traces for each thread—is very performance sensitive because it fires at 100Hz+. Avoiding excessive heap allocations is critical, and all Objective-C data structures are heap allocated, making them unsuitable. Plain C lacks real data structures, so C++ is the most logical choice given its performance characteristics and good interop with both C and Objective-C.
