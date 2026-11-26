import SwiftUI

struct AppHangButton: View {
    var body: some View {
        Button(action: triggerAppHang) {
            Text("Trigger App Hang")
        }
    }

    @inline(never)
    func triggerAppHang() {
        simulateDatabaseQuery()
        simulateImageProcessing()
        simulateSleep()
        simulateNetworkParsing()
    }

    @inline(never)
    func simulateDatabaseQuery() {
        performTableScan()
        performIndexLookup()
    }

    @inline(never)
    func performTableScan() {
        var accumulator: Double = 0
        for i in 0..<5_000_000 {
            accumulator += sin(Double(i) * 0.0001)
        }
        blackhole(accumulator)
    }

    @inline(never)
    func performIndexLookup() {
        var accumulator: Double = 0
        for i in 0..<3_000_000 {
            accumulator += cos(Double(i) * 0.0002)
        }
        blackhole(accumulator)
    }

    @inline(never)
    func simulateImageProcessing() {
        applyGaussianBlur()
        resizeBuffer()
    }

    @inline(never)
    func applyGaussianBlur() {
        var accumulator: Double = 0
        for i in 0..<4_000_000 {
            accumulator += sin(Double(i) * 0.00015) * cos(Double(i) * 0.00025)
        }
        blackhole(accumulator)
    }

    @inline(never)
    func resizeBuffer() {
        var accumulator: Double = 0
        for i in 0..<2_000_000 {
            accumulator += log(Double(i + 1)) * 0.001
        }
        blackhole(accumulator)
    }

    @inline(never)
    func simulateNetworkParsing() {
        deserializeJSON()
        validateSchema()
    }

    @inline(never)
    func deserializeJSON() {
        var accumulator: Double = 0
        for i in 0..<3_000_000 {
            accumulator += Double(i % 127) * 0.0003
        }
        blackhole(accumulator)
    }

    @inline(never)
    func validateSchema() {
        var accumulator: Double = 0
        for i in 0..<2_000_000 {
            accumulator += atan(Double(i) * 0.0001)
        }
        blackhole(accumulator)
    }

    @inline(never)
    func blackhole(_ value: Double) {
        _ = value
    }

    @inline(never)
    func simulateSleep() {
        usleep(1_500_000)
    }
}
