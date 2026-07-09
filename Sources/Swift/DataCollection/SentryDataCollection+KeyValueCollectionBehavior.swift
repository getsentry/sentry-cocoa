extension SentryDataCollection {
    /// Controls how key-value data (headers, cookies, query params) is collected and filtered.
    ///
    /// Key names are always included in the event regardless of mode. This enum controls which
    /// **values** are sent in plaintext vs. replaced with `[Filtered]`.
    ///
    /// DenyList and AllowList are mutually exclusive — the enum makes it impossible to set both.
    ///
    /// - SeeAlso: [Data Collection Spec — Key-Value Collection Behavior](https://develop.sentry.dev/sdk/foundations/client/data-collection/#option-types)
    public enum KeyValueCollectionBehavior: Equatable, Hashable {

        /// Do not collect this category at all — no keys or values are attached.
        case off

        /// Collect all key names and values. Replace values for keys matching the built-in
        /// sensitive denylist with `[Filtered]`. The provided `terms` **extend** the built-in
        /// denylist.
        /// - Parameter terms: Extra terms to add to the built-in denylist. Defaults to none.
        case denyList(terms: [String] = [])

        /// Collect all key names. **Only** keys in `terms` send their real value; all others
        /// are replaced with `[Filtered]`. Sensitive denylist scrubbing still applies — keys
        /// matching a sensitive pattern are always scrubbed even if they appear in `terms`.
        /// - Parameter terms: The keys whose values should be sent in plaintext.
        case allowList(terms: [String])
    }
}
