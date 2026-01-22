protocol TelemetryBufferMetadata {
    var environment: String { get }
    var releaseName: String? { get }
    var installationId: String? { get }
}
