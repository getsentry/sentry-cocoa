# XcodeGen Version Drift Design

## Goal

Extend the existing tooling version drift checks from SwiftLint and clang-format to XcodeGen.

## Version Record

- Add `scripts/.xcodegen-version`.
- Record the normalized numeric output of `xcodegen --version`, currently `2.46.0`.
- Keep one version file per tool, matching the existing SwiftLint and clang-format pattern.

## Update and Check Flow

- Update `scripts/update-tooling-versions.sh` to extract the numeric version from XcodeGen's `Version: <version>` output and write it to `.xcodegen-version`.
- Update `scripts/check-tooling-versions.sh` to extract the installed XcodeGen version and compare it with `.xcodegen-version`.
- Report an XcodeGen mismatch with the expected and installed versions.
- Preserve the existing combined failure behavior and resolution message.

## CI Integration

- Add `scripts/.xcodegen-version` to the Homebrew cache key.
- Add the version file to tooling and build-related workflow file filters where XcodeGen changes must trigger validation.
- Extend `.github/workflows/auto-update-tools.yml` to create a dedicated XcodeGen version update PR, parallel to the SwiftLint and clang-format PRs.

## Error Handling

- Continue using `set -euo pipefail`, so a missing XcodeGen executable or unparseable command failure stops the check or update.
- Compare only normalized numeric version strings.
- Do not change how XcodeGen is installed. This remains version drift detection rather than installation pinning.

## Verification

- Run the tooling version check with the recorded local XcodeGen version.
- Exercise mismatch detection using a temporary changed version record, restoring the file afterward.
- Run shell linting and formatting checks relevant to the changed scripts and workflows.
- Validate the edited GitHub Actions workflow syntax.
