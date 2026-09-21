# MetricKit Flamegraph Explorer

Use the [flamegraph viewer](index.html) to inspect MetricKit call stacks in a browser. The optional [symbolication script](symbolicate.sh) adds function names and available source locations to a separate JSON file before you open it in the viewer.

The viewer is a self-contained HTML file. It needs no server, build step, or external dependencies, and does not upload your reports. Symbolication runs separately on macOS and can use local build artifacts, Xcode device symbols, or Sentry debug files.

## Open a report

Run commands from the repository root:

```sh
open Utils/MetricKitExplorer/index.html
```

1. Choose a JSON file using the file picker. The viewer accepts a call-stack tree with top-level `callStacks`, or a report containing that tree under `callStackTree`.
2. Select the binaries that belong to your application in the initial dialog. You can change this selection later under **Options**.
3. Inspect the graph:
   - Frame widths represent sample counts, not elapsed time.
   - Hover or focus a frame for its function, binary, addresses, UUID, sample count, and available source location.
   - Click a frame or press Enter to zoom into its branch. Use **Reset zoom** to restore the view.
   - Search by function, binary, address, or source path.
   - Filter **All Frames**, **Application Frames**, or **System Frames**. Unselected binaries count as system/unclassified frames.
   - Use **Options → Invert stack tree** to place roots at the bottom.
   - Pinch to zoom horizontally. Ordinary scrolling remains native, and does not change the graph's scale.

Raw reports work without symbolication. Repository examples are available in [Tests/Resources/MetricKitCallstacks](../../Tests/Resources/MetricKitCallstacks).

> [!NOTE]
> Application/system classification uses your binary selections, not function names. A framework-looking function such as `CIContext.init()` can be a compiler-generated wrapper inside your app binary. Resolving that wrapper does not mean the framework's own frames have been symbolicated.

## Symbolication requirements

The script requires:

- macOS developer tools providing `xcrun` and `atos`.
- Bash. The script supports the macOS-bundled Bash 3.2.
- Decimal-enabled `jq`, tested with jq 1.8.2. Check your installation with `jq -en 'have_decnum'`. Decimal support preserves address literals that exceed JavaScript's exact integer range.
- The legacy **`sentry-cli`**, tested with version 3.8.0, for local `debug-files find` and `debug-files check` operations.

Remote fallback additionally requires the newer **`sentry` CLI 0.45.0+**, authenticated for the target project and permitted to download debug files. These are two distinct CLI executables. The newer CLI is not required when using `--local-only` or when all eligible images resolve locally.

## Symbolicate application frames locally

Replace the example paths with your report and a matching build artifact:

```sh
./Utils/MetricKitExplorer/symbolicate.sh \
  --report /path/to/MXDiagnosticPayload.json \
  --local-symbols /path/to/MyApp.app.dSYM \
  --local-only \
  --verbose
```

The output defaults to `MXDiagnosticPayload.symbolicated.json` beside the input. Open this output with the same viewer.

`--local-symbols` accepts a Mach-O binary, `.app`, `.dSYM`, or build directory. Repeat the option to supply fallback locations for images not found in the automatically selected device-symbol cache. Within these fallback paths, dSYM bundles are searched before other local artifacts. Local files are used in place rather than copied into a cache.

> [!NOTE]
> Symbols must match the image UUID from the captured report. Rebuilding the same source code or finding a binary with the same name is not sufficient. Architecture is inferred from the matching artifact, not from the report's device architecture. For example, an `arm64e` device report can contain an `arm64` app binary.

## Include Apple framework and system symbols

The script first uses `diagnosticMetaData.deviceType`, `osVersion`, and `platformArchitecture` to locate the exact Xcode iOS device-symbol cache. For example, a report identifying `iPhone13,2`, `iPhone OS 27.0 (24A437)`, and `arm64e` selects:

```text
~/Library/Developer/Xcode/iOS DeviceSupport/iPhone13,2 27.0 (24A437)/arm64e/Symbols
```

If that directory exists, its symbols are searched first. No extra flag is needed. The device architecture selects the cache directory only, not the architecture used to symbolicate app frames.

If the metadata is absent or unsupported, the cache is missing, or an image is not found there, the script tries the supplied `--local-symbols` paths. You can provide an alternative device-symbol location explicitly:

```sh
./Utils/MetricKitExplorer/symbolicate.sh \
  --report /path/to/MXDiagnosticPayload.json \
  --local-symbols /path/to/MyApp.app.dSYM \
  --local-symbols "$HOME/Library/Developer/Xcode/iOS DeviceSupport/<device and OS build>/arm64e/Symbols" \
  --local-only \
  --output /path/to/MXDiagnosticPayload.with-system-symbols.json \
  --verbose
```

The script checks each image's UUID and architecture before using its symbols. Merely matching the OS marketing version is not sufficient. System symbols often provide function names without source files or line numbers, and some frames may remain unresolved even with the matching cache.

The script never performs a broad filesystem or well-known-location search. If neither automatic discovery nor explicit fallback paths provide symbols, frames remain unresolved with `--local-only`. Without `--local-only`, the existing Sentry fallback applies.

## Fall back to Sentry debug files

Omit `--local-only` to download symbols for images not matched locally:

```sh
./Utils/MetricKitExplorer/symbolicate.sh \
  --report /path/to/MXDiagnosticPayload.json \
  --local-symbols /path/to/Build/Products \
  --org your-org \
  --project your-project \
  --output /path/to/MXDiagnosticPayload.remote.symbolicated.json \
  --verbose
```

Organization and project can also come from `SENTRY_ORG` / `SENTRY_PROJECT` or the newer CLI's configured defaults. Remote lookups use `sentry api`. The report itself is not uploaded, but its image UUIDs are sent as lookup queries.

Validated downloads are cached under:

```text
~/Library/Caches/io.sentry.tools.metrickit-explorer/dsyms
```

Use `--cache-dir` to select another location. Cached files are validated again before use.

> [!WARNING]
> Permission to list debug files does not necessarily include permission to download them. HTTP 403 produces a warning and leaves affected frames unresolved. Other API failures stop processing without writing an output report. Use matching local symbols if remote downloads are unavailable.

## Output and diagnostics

- The input report is never modified. Existing output files, including symlinks, are never overwritten. Choose a new `--output` path for another run.
- Resolved frames receive a `symbolication` object with `function` and, when available, `file` and `line`. Original nesting, sample counts, metadata, address literals, and unresolved frames are preserved in the output JSON.
- `--verbose` / `-v` writes timestamped progress to stderr, including search scope, image progress, cache hits and misses, API activity, `atos` timings, and the final result. It does not enable CLI HTTP tracing or dump credentials and response bodies.
- Use `--arch` only when you need an explicit architecture override. Normally the matching symbols determine the correct architecture for each image.
- Missing UUIDs, unavailable symbols, or offsets that cannot resolve to a function leave frames unchanged. A partially symbolicated report is still usable in the viewer.

For the complete option list:

```sh
./Utils/MetricKitExplorer/symbolicate.sh --help
```

> [!WARNING]
> Reports, symbolicated source paths, screenshots, and verbose logs can contain project or device details. Review them before attaching them to a public issue or pull request.

## Run tests

From this directory, run `make test`, or from the repository root:

```sh
make -C Utils/MetricKitExplorer test
```

The symbolication tests require macOS developer tools, decimal-enabled jq, and `sentry-cli`. The viewer tests also require Node.js, `playwright-cli`, and its configured browser. These tools must already be installed. The newer `sentry` CLI and a Sentry login are not needed for tests.

Tests live in `tests/`. The shell suite compiles its own Mach-O/dSYM fixtures and creates a private temporary home directory. Sentry API calls are mocked, and the legacy CLI wrapper rejects unbounded discovery. The browser suite uses repository JSON fixtures and synthetic symbol annotations, not private diagnostic reports. Temporary artifacts are removed on success and retained with their location printed on failure.

To run only one suite:

```sh
make -C Utils/MetricKitExplorer test-symbolication
make -C Utils/MetricKitExplorer test-viewer
```
