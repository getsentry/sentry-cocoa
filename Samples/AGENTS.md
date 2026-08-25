# Samples

> Scope: `Samples/**`. Also follow [root instructions](../AGENTS.md).

## Layout

- Put source in `Sources/`, assets in `Resources/`, and Info.plist, entitlements, and xcconfig files in `Configuration/`
- Preserve empty required directories with `.gitkeep`

## Project Generation

- Always generate sample projects through Make targets, never by invoking `xcodegen` directly
- Generate one project with `make xcode-ci-<name>`
- Generate all projects with `make xcode-ci`
- Generate and build one sample with `make build-sample-<name>`

## Validation

- Build affected samples with `make build-sample-<name>`
- Run affected UI tests with `make test-sample-<name>-ui` when behavior changes
- Use `make test-ui-critical` for critical UI coverage
- Follow assertion conventions in [`Tests/AGENTS.md`](../Tests/AGENTS.md)
