import SentrySwiftUI
import SwiftUI

struct DelayedFullDisplayView: View {

    @State private var isDelayedContentVisible = false

    @State private var statusRefreshCounter = 0
    @State private var isTTIDReported = false
    @State private var isTTFDReported = false

    var body: some View {
        VStack {
            SentryTracedView("Content", waitForFullDisplay: true) {
                Text("Initial Content")
                    .accessibilityIdentifier("content.initial")
                Button("Show Delayed Content") {
                    // Cause a custom delay to simulate loading content
                    // The full content will then report that it is fully displayed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isDelayedContentVisible = true
                    }
                }
                .accessibilityIdentifier("button.trigger-delayed-content")
                if isDelayedContentVisible {
                    Text("Delayed Content")
                        .accessibilityIdentifier("content.delayed")
                        .onAppear {
                            SentrySDK.reportFullyDisplayed()
                        }
                } else {
                    ProgressView()
                }
            }
            Spacer()
            VStack {
                Button("Refresh TTFD / TTID Status") {
                    guard let tracer = SentrySDK.span as? SentryTracer else {
                        return
                    }
                    // Check if the spans are found in the current tracer
                    // Afterwards increment the counter so we can definitely tell that the status was refreshed
                    isTTIDReported = isTTIDSpanFound(tracer: tracer)
                    isTTFDReported = isTTFDSpanFound(tracer: tracer)
                    statusRefreshCounter += 1
                }
                .accessibilityIdentifier("button.update-ttfd-ttid-status")
                Text("Status Refresh Counter: \(statusRefreshCounter)")
                    .accessibilityIdentifier("label.status-refresh-counter")
                Toggle(isOn: $isTTIDReported) {
                    Text("TTID Reported")
                }
                .accessibilityIdentifier("check.ttid-reported")
                Toggle(isOn: $isTTFDReported) {
                    Text("TTFD Reported")
                }
                .accessibilityIdentifier("check.ttfd-reported")
            }
            .font(.caption)
        }
    }

    func isTTIDSpanFound(tracer: SentryTracer) -> Bool {
        tracer.children.contains { $0.spanDescription?.contains("initial display") == true } == true
    }

    func isTTFDSpanFound(tracer: SentryTracer) -> Bool {
        tracer.children.contains { $0.spanDescription?.contains("full display") == true } == true
    }
}
