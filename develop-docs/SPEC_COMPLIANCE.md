# SDK Specification Compliance

`sentry-spec-compliance.json` records specification sections implemented by the SDK.

- Update `last_updated` when changing compliance declarations.
- Set each implemented section to the latest specification version its implementation satisfies.
- Use `non_applicable` only when an entire section requires no Cocoa implementation.
- Leave applicable but incomplete sections absent.
- Set the spec-level `version` to the highest fully implemented version. Use `0.0.0` until the first complete version is implemented.

## Proof-of-Concept Limitation

Section-level tracking cannot represent partially applicable sections. For example, a section may combine supported HTTP controls with queue or GenAI categories that Cocoa does not collect. Such a section remains absent until the format supports requirement-level applicability or the specification splits it into smaller sections.
