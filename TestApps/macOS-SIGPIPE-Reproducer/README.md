# macOS SIGPIPE reproducer

Shows which thread receives a process-wide SIGPIPE while the SDK runs ([#1589](https://github.com/getsentry/sentry-cocoa/issues/1589)).

On Darwin, a write to a closed pipe or socket raises SIGPIPE for the whole process, and the kernel delivers it to the first non-workqueue thread that does not block it. The tool starts the SDK from source, blocks SIGPIPE on the main thread, writes to a closed pipe, and prints the thread that received the signal.

Run it from a terminal, not from Xcode: SentryCrash does not install the mach exception handler while a debugger is attached.

```sh
swift run --package-path TestApps/macOS-SIGPIPE-Reproducer
```

Run it on `main` and on the fix branch and compare the `RESULT` line:

- `an SDK thread received the signal` (exit code 1): the kernel picked a thread that `SentrySDK.start` created. A real app would crash with that thread's stack in the report.
- `no thread received the signal` (exit code 0): every thread that could receive the signal blocks it, so the kernel keeps it pending and the process keeps running.

If the signal stays pending until the tool resumes the suspended secondary exception handler thread, the kernel had assigned it to that thread. Set `SENTRY_DEBUG=1` for SDK logs.
