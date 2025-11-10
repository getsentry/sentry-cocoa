# Opaque Clipping and Redaction – Design Notes

## Summary

We treat a view as “opaque enough to clear/redact content behind it” only when we are certain it fully hides what’s below. To avoid leaks like a semi‑transparent full‑screen overlay clearing sensitive text, we use a strict definition of opacity.

## Why strict?

- Semi‑transparent overlays (e.g. PopupDialog) often render a dimming tint in a child subview with alpha < 1. The container may look like a blocker, but the effective result is translucent.
- A false positive (classifying translucent as opaque) can leak sensitive content. A false negative only loses an optimization (we still redact lower views).

## The rule we use

We classify a view as opaque only if:

1. presentation layer `opacity == 1.0` (no global transparency)
2. `view.backgroundColor` is fully opaque (alpha == 1.0)
3. `layer.backgroundColor` is fully opaque (alpha == 1.0)
4. `view.isOpaque == true` and `layer.isOpaque == true`

Additionally, we allow an explicit override via `SentryRedactViewHelper.shouldClipOut(view)` to force clip‑out.

This avoids misclassifying composite overlays where a child view (not the container) provides the semitransparent effect.

## Tests: Arrange explicitly

When a test expects “opaque clipping”, explicitly arrange the view to satisfy the strict rule:

- `view.alpha = 1.0`
- `view.backgroundColor` with alpha 1.0
- `view.isOpaque = true`
- `view.layer.isOpaque = true`
- `view.layer.backgroundColor` with alpha 1.0

For scenarios that should not clip (e.g. translucent overlay), omit these properties or use alpha < 1.0.

## PopupDialog edge case

- Structure: a clear container with a child “overlay” subview filling bounds with `alpha < 1`. The container is not truly opaque; requiring BOTH view and layer to present fully opaque backgrounds (and isOpaque hints) prevents misclassification.

## Tradeoffs

- Strict rule: prevents leaks, might skip some clip‑outs (optimization only).
- If an app truly has a fully opaque blocker, it can set the explicit opaque properties or use `shouldClipOut`.
