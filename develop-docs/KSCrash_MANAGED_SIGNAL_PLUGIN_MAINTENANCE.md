# KSCrash Managed Signal Plugin Maintenance

## Scope and ownership

The managed Signal plugin is SDK-side interoperability for .NET/Mono on Apple platforms and
SDKs built on top of sentry-cocoa. It is enabled only in products compiled with
`SENTRY_CRASH_MANAGED_RUNTIME`; normal sentry-cocoa users continue to use KSCrash's built-in Signal
monitor.

The implementation lives in
[`SentryKSCrashManagedSignal.c`](../Sources/Sentry/KSCrash/SentryKSCrashManagedSignal.c), with an
[internal header](../Sources/Sentry/include/SentryKSCrashManagedSignal.h). Report-persistence policy
remains in
[`SentryKSCrashReportWriterCallbacks.c`](../Sources/Sentry/KSCrash/SentryKSCrashReportWriterCallbacks.c).

The plugin intentionally stays close to `KSCrashMonitor_Signal.c`, with these Sentry-specific
changes:

- a constructor installs the signal anchor _before_ the managed runtime
- KSCrash's built-in Signal monitor is omitted and the Sentry monitor adopts KSCrash's callbacks
  exactly once, publishing a validated, immutable process-lifetime snapshot
- per-thread, one-shot `ignoreNextSignal` state is owned by the SDK
- interrupted installation restores only published predecessors and stops installing
- enablement becomes observable only after all handlers are installed
- fatal forwarding keeps KSCrash's serial predecessor restore and reapplies the current
  signal's immutable predecessor immediately before re-raising
- existing alternate stacks are borrowed, and unused allocations are reclaimed only before a
  handler could reference them
- Sentry's SDK-close report-persistence policy is enforced by the downstream
  `willWriteReport` callback
- managed builds configure KSCrash's generic Mach exception mask so `EXC_BAD_ACCESS` and
  `EXC_ARITHMETIC` reach the managed runtime's signal path

sentry-cocoa owns the native adapter and fake-handler contract tests. Downstream SDKs own validation
with their real .NET/Mono/AOT runtime. sentry-cocoa must not add a managed runtime merely for these
tests.

## Source synchronization rules

The current dependency and Signal-monitor synchronization baseline is the getsentry 2.6 backport
revision `18a633dec20c265f03386294f9d82d208bb13094`. Its `KSCrashMonitor_Signal.c` is byte-identical
to the previously reviewed dependency revision; the added reserved-thread lookup, configurable Mach
exception mask, and C++ swapper page-protection fix do not modify that monitor.

Keep the SDK implementation structurally close to the corresponding KSCrash Signal monitor:

- keep upstream function order, comments, and naming where practical
- record the exact upstream KSCrash revision used as the synchronization baseline in the source
- mark intentional divergence with `SENTRY MANAGED SIGNAL DIFFERENCE BEGIN/END` comments
- do not include KSCrash's private `.c` file or depend on private monitor symbols
- port relevant async-signal-safety and correctness fixes rather than refactoring the two monitors
  independently

## KSCrash upgrade procedure

1. Note the old and new KSCrash revisions
2. Review the revision range for changes to:
   - `KSCrashMonitor_Signal.c` and its header
   - fatal-signal definitions and signal-stack behavior
   - machine-context and unwind helpers
   - `KSCrashMonitorAPI`, monitor context, and exception-handling requirements
   - plugin registration, enablement, ordering, and async-safe disable behavior
3. Compare the new upstream Signal monitor with the SDK-side copy. Port every applicable safety
   or correctness change, preserving the marked Sentry differences.
4. Update the synchronization-baseline revision in the Sentry source
5. Build V10 both with and without `SENTRY_CRASH_MANAGED_RUNTIME`
6. Run the focused installation tests below, then normal signal coverage to prove the default
   KSCrash path is unchanged
7. Run the managed-runtime CrashE2E matrix on macOS and iOS:
   - forwarded native signal
   - managed-consumed signal
   - Swift and Objective-C one-shot suppression
   - pre-SDK signal
   - post-close signal
   - close followed by reinitialization
8. Run the ordinary Signal and ignored-Signal scenarios, post-close Signal and NSException no-event
   scenarios, and close/reinitialize/Signal one-event scenario on macOS and iOS. This proves the
   default monitor path and generic lifecycle callback remain intact.
9. Ask downstream SDK owners to run real-runtime validation when the KSCrash change, Apple runtime,
   or .NET/Mono version could affect signal interoperability.

## Installation tests

```sh
make test-macos-v10 FOR_AGENTS=true ONLY_TESTING=SentryTestsV10/SentryKSCrashManagedSignalTests
make test-ios-v10 FOR_AGENTS=true ONLY_TESTING=SentryTestsV10/SentryKSCrashManagedSignalTests
```

[`SentryKSCrashManagedSignalTests.m`](../Tests/SentryTests/Integrations/KSCrash/SentryKSCrashManagedSignalTests.m)
compiles an isolated copy of the SDK-side monitor with renamed external symbols, no constructor,
and substituted `sigaction`, `sigaltstack`, `raise`, and allocation functions. This permits
deterministic interruption, failure injection, and ownership checks without replacing the test
runner's actual handlers. Three tests additionally exercise real `sigaltstack` registration on
short-lived worker threads, restoring each worker's original stack before it exits. Callback tests
substitute context/unwind helpers and intercept readiness publication using Clang's actual C11
atomic store, allowing deterministic signal delivery and reentry at that boundary. Let's keep
production test hooks at a minimum or ideally out, if possible.

Installation publishes each immutable predecessor before exposing that signal's anchor. Restoration
acquires only that published prefix. An interrupted installer must stop, including undoing a
`sigaction` that completed after restoration. The final transition to `Installed` must never overwrite
a terminal state. Tests cover first/final-handler delivery, in-flight installation, query/install
failure, `SIG_IGN`, and adoption without reinstallation.

The first fatal handler publishes terminal `Uninstalled` before KSCrash's serial restore loop
finishes. A nested handler therefore cannot use that state as proof that its own predecessor is
already active. Preserve the upstream-derived serial loop, then idempotently reapply the current
signal's published predecessor immediately before `raise`. The harness delivers a nested signal both
between restoration writes and immediately before its own predecessor write takes effect, and checks
the disposition at the nested re-raise boundary. This guard requires no work queue, waiting,
locks, allocation, production hooks, or real fatal-signal test process.

These tests do not validate kernel signal delivery or arbitrary concurrent fatal deliveries. Let's not
add scheduler machinery or a real-fatal-signal framework solely for that edge case without a concrete
regression. The deterministic forwarding contract extends, rather than replaces, CrashE2E.

## One-shot signal suppression

`ignoreNextSignal` registers one entry per calling thread outside signal context. The signal handler
traverses the append-only list, compares the accepted `pthread_self()` identity, and
atomically consumes the pending signal without allocation or locking. A mismatching delivery still
consumes the token; this preserves the existing hybrid-SDK contract. Repeated registration on the
same thread replaces the pending signal rather than allocating another entry.

The pthread-key destructor clears both the pending signal and thread identity. Entries remain
allocated because a signal handler may still be traversing the list, but a later thread that receives
the same pthread identity cannot match the cleared entry. Tests cover matching one-shot behavior,
mismatch consumption, replacement, thread isolation, and identity clearing after thread exit. They
do not attempt to "force" Darwin to reuse a pthread identity through scheduler machinery.

## Report-persistence lifecycle

KSCrash handlers and plugin callbacks are process-lifetime. Sentry therefore keeps them installed
across SDK close and controls only report persistence through a lock-free downstream atomic. The
state starts inactive, becomes active after initial installation or already-installed reinitialization,
and returns inactive on close. `willWriteReport` applies the inactive policy generically by clearing
both `shouldWriteReport` and `shouldRecordAllThreads`, so Signal, Mach, C++, and NSException agree.

This veto occurs after KSCrash's initial exception handling and contextual enrichment.
It does not prevent earlier thread suspension/enumeration or lifecycle bookkeeping.

Tests cover active, inactive, null-plan, and reactivated callback behavior. CrashE2E proves
install/close/reinitialize transitions for ordinary and managed Signal paths and post-close
NSException behavior.

## Callback publication

KSCrash supplies process-lifetime reporting functions. The first initialization with both `notify`
and `handle` present claims the single writer and copies those two functions into monitor storage.
The other callback fields are unused and are not copied. The monitor currently uses the public
legacy `handle` callback provided by both the pinned 2.6 line and the reviewed 3.x headers.

We must review this requirement whenever upgrading KSCrash.

A release store publishes readiness only after the copy is complete. The signal handler uses an
acquire load and never waits for initialization: before readiness it only restores/forwards. Losing
or reentrant initializers return without waiting or modifying the snapshot, including while the
winning initializer is still pending. Invalid input neither publishes nor claims initialization, so
a later valid call can succeed. The caller's table need only live for the duration of the call;
KSCrash owns the lifetime of the copied function targets.

SDK close/reinitialize does not reset this state. Tests cover invalid input/retry, caller-table
independence, same/different repeated tables, concurrent initializers, reentry between `notify` and
`handle`, and both delivery and reentry before readiness publication. The same harness also checks
report-context population, null/immediate-exit bailout, and `SIGTERM`'s no-report requirements.

## Alternate-stack ownership

`sigaltstack` is per-thread. Installation borrows an existing enabled stack, including when the thread
is already on it. The SDK _must not_ replace or free that stack. Only a disabled stack causes us to
allocate and register our own buffer. This does not provision stacks for other threads (including,
obviously, the managed runtime ones).

Before any successful handler installation, failure cleanup may reclaim the unused predecessor
table and owned stack. A registered owned stack must first be safely disabled. Darwin validates
`ss_size >= MINSIGSTKSZ` even for `SS_DISABLE`, so cleanup preserves the owned stack's valid size
instead of replaying a zero-sized initial descriptor. If querying/disabling fails, the thread is on
the stack, or another owner changed the registration, we keep the buffer rather than free possibly
referenced memory. We always leave a replacement owner's registration untouched.

After any handler becomes reachable, we keep the predecessor table and owned stack for process
lifetime, even if a later installation step fails. A handler may already be using them. SDK close,
monitor disablement, and fatal handler restoration must not free or detach them. The early-failure
cleanup helper is never called from a signal handler.

## Optional automation

A comparison script may print the relevant file diff between the old and new KSCrash pins.
If manual synchronization becomes a burden, we keep the intentional Sentry delta as a patch that can
be applied to a fresh upstream Signal monitor and a resulting conflict could then lead to a review.
I refrained from adding generation machinery and hope to keep it that way until repeated upgrades
demonstrate that the simpler source baseline and isolated diffs are insufficient.
