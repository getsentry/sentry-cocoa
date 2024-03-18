import Foundation

/// Encodes the metrics into a Statsd compatible format.
/// See https://github.com/statsd/statsd#usage and https://getsentry.github.io/relay/relay_metrics/index.html for more details about the format.
func encodeToStatsd(flushableBuckets: [BucketTimestamp: [Metric]]) -> Data {
    var statsdString = ""

    for bucket in flushableBuckets {
        let timestamp = bucket.key
        let buckets = bucket.value
        for metric in buckets {

            statsdString.append(sanitize(key: metric.key))
            statsdString.append("@")

            statsdString.append(metric.unit.unit)

            for serializedValue in metric.serialize() {
                statsdString.append(":\(serializedValue)")
            }

            statsdString.append("|")
            statsdString.append(metric.type.rawValue)

            var firstTag = true
            for (tagKey, tagValue) in metric.tags {
                let sanitizedTagKey = sanitize(key: tagKey)

                if firstTag {
                    statsdString.append("|#")
                    firstTag = false
                } else {
                    statsdString.append(",")
                }

                statsdString.append("\(sanitizedTagKey):")
                statsdString.append(sanitize(value: tagValue))
            }

            statsdString.append("|T")
            statsdString.append("\(timestamp)")
            statsdString.append("\n")
        }
    }

    return statsdString.data(using: .utf8) ?? Data()
}

private func sanitize(key: String) -> String {
    return key.replacingOccurrences(of: "[^a-zA-Z0-9_/.-]+", with: "_", options: .regularExpression)
}

private func sanitize(value: String) -> String {
    return value.replacingOccurrences(of: "[^\\w\\d\\s_:/@\\.\\{\\}\\[\\]$-]+", with: "", options: .regularExpression)
}
