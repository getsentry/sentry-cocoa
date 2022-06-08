# Develop Documentation

This page contains internal documentation for development.

## Code Signing

This repository follows the [codesiging.guide](https://codesigning.guide/) in combination with [fastlane match](https://docs.fastlane.tools/actions/match/).
Therefore the sample apps use manual code signing, see [fastlane docs](https://docs.fastlane.tools/codesigning/xcode-project/):
> In most cases, fastlane will work out of the box with Xcode 9 and up if you selected manual code signing and choose a provisioning profile name for each of your targets.

Reach out to @philipphofmann if you need access to the match git repository.

## Unit Tests with Thread Sanitizer

CI runs the unit tests for one job with thread sanitizer enabled to detect race conditions.
The Test scheme of Sentry uses `TSAN_OPTIONS` to specify the [suppression file](../Tests/ThreadSanitizer.sup) to ignore false positives or known issues.
It's worth noting that you can use the `$(PROJECT_DIR)` to specify the path to the suppression file.
To run the unit tests with the thread sanitizer enabled in Xcode click on edit scheme, go to tests, then open diagnostics, and enable Thread Sanitizer.

### Further Reading

* [ThreadSanitizerSuppressions](https://github.com/google/sanitizers/wiki/ThreadSanitizerSuppressions)
* [Running Tests with Clang's AddressSanitizer](https://pspdfkit.com/blog/2016/test-with-asan/)
* [Diagnosing Memory, Thread, and Crash Issues Early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)
* [Stackoverflow: ThreadSanitizer suppression file with Xcode](https://stackoverflow.com/questions/38251409/how-can-i-suppress-thread-sanitizer-warnings-in-xcode-from-an-external-library)

## UI Tests

CI runs UI tests on simulators via the `test.yml` workflow, and on devices via `saucelabs-UI-tests.yml`. All are run for each PR, and Sauce Labs tests also run on a nightly cron schedule.

### Performance benchmarking

* [Performance benchmarks](../Samples/iOS-Swift/iOS-SwiftUITests/SDKPerformanceBenchmarkTests.swift) calculates the overhead CPU usage of the Sentry profiler. These only run on devices running the latest iOS major series.

The benchmark runs in a UI test ([`SDKPerformanceBenchmarkTests`](../Samples/iOS-Swift/iOS-SwiftUITests/SDKPerformanceBenchmarkTests.swift)) using the iOS-Swift sample app, which has a view controller for this purpose: [`PerformanceViewController`](../Samples/iOS-Swift/iOS-Swift/ViewControllers/PerformanceViewController.swift).

#### Test procedure

- Tap the button to start a Sentry transaction with the associated profiling.
- Run a loop performing large amount of calculations to use as much CPU as possible. This simulates something an app developer would want to profile in a real world scenario.
- While benchmarking, run a sampling profiler at 10 Hz to calculate the CPU usage of each thread; in particular the Sentry profiler's, to calculate its relative usage.
- Tap the button to stop the transaction after waiting for 15 seconds.
- Grab the value written by the test app in a UITextField accessible to the UI test runner so it can extract the value and use it in an `XCTAssert`.

#### Test Plan
- Run the procedure 5 times, then assert that the 90th percentile remains under 5% so we can be alerted via CI if it spikes.

## Auto UI Performance Class Overview

![Auto UI Performance Class Overview](./auto-ui-performance-tracking.svg)

## Performance API Overview

![Performance API Overview](./performance-api.svg)

## Generating classes

You can use the `generate-classes.sh` to generate ViewControllers and other classes to emulate a large project. This is useful, for example, to test the performance of swizzling in a large project without having to check in thousands of lines of code.

## Generating Diagrams

The diagrams are created with [PlantUml](http://plantuml.com). The advantage of PlantUml
over other diagram tools is that you describe the diagrams with text, and you don't have
to worry about UML and layout, which can be time-consuming for changes. Furthermore, the
diagrams can be stored in git.

With [Visual Studio Code](https://code.visualstudio.com/) and the
[PlantUml Plugin](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml#user-content-use-plantuml-server-as-render)
you can create diagrams, view them and export them. If you don't want to use Visual Studio Code,
there are many [alternatives](http://plantuml.com/running).

For learning the syntax and quickly playing around you can check out [Plant Text](https://www.planttext.com/).

### Visual Studio Code Setup

Visual Studio Code needs a rendering engine for PlantUml. We recommend using the following Docker image:

```sh
docker run -d -p 8080:8080 plantuml/plantuml-server:jetty
```

To ensure the rendering server is running properly, visit with `localhost:8080`.

Finally, you have to configure the rendering server in Visual Studio Code. For this, open the settings of Visual Studio Code. Choose `Extensions > PlantUML configuration`. Click on `Edit in settings.json`. Then paste the following into the config:

```json
{
  "plantuml.server": "http://localhost:8080",
  "plantuml.render": "PlantUMLServer"
}
```

Save the settings and you should be able to render a diagram.

You can find the official guide here: [configure a rendering server](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml#user-content-use-plantuml-server-as-render).

## Decision Log

### Not capturing screenshots for crashes

Date: April 21st 2022
Contributors: @philipphofmann, @brustolin

We decided against capturing screenshots for crashes because we must only call [async-safe functions](https://man7.org/linux/man-pages/man7/signal-safety.7.html) in signal handlers. Capturing a screenshot requires Objcetive-C code, which is not async safe.
We could create the crash report first, write it to disk and then call Objective-C to get the screenshot. The outcome in such a scenario would be undefined, potentially breaking other signal handlers. We decided against this approach because we don't want to break the contract of signal handlers only calling async-safe functions.

Related links:

- https://github.com/getsentry/sentry-cocoa/pull/1751

