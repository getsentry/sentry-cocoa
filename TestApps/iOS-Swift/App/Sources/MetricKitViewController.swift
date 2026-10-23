import Foundation
import SentrySwift
import UIKit

final class MetricKitViewController: UIViewController {
    private let diskWriteStressor = MetricKitDiskWriteStressor()
    private let cpuStressor = MetricKitCPUStressor()
    private let hangStressor = MetricKitHangStressor()

    @IBAction func triggerCrashDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDK.logger.fatal(
            "MetricKit crash stressor started",
            attributes: ["stressor": "crash"]
        )
        SentrySDK.crash()
    }

    @IBAction func triggerDiskWriteExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        diskWriteStressor.start()
    }

    @IBAction func triggerCPUExceptionDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        cpuStressor.start()
    }

    @IBAction func triggerCatalogHangDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        hangStressor.start(workload: "catalog_refresh") {
            try MetricKitCatalogService().refreshCatalog()
        }
    }

    @IBAction func triggerCheckoutHangDiagnostic(_ sender: UIButton) {
        highlightButton(sender)
        hangStressor.start(workload: "checkout") {
            try MetricKitCheckoutService().checkout()
        }
    }
}

private final class MetricKitCPUStressor {
    private static let duration: TimeInterval = 180

    private let queue = DispatchQueue(
        label: "io.sentry.sample.metrickit.cpu",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let lock = NSLock()
    private var running = false

    func start() {
        lock.lock()
        guard !running else {
            lock.unlock()
            SentrySDK.logger.warn(
                "MetricKit CPU stressor already running",
                attributes: ["stressor": "cpu"]
            )
            return
        }
        running = true
        lock.unlock()

        let workerCount = ProcessInfo.processInfo.activeProcessorCount
        let group = DispatchGroup()
        let endTime = Date().addingTimeInterval(Self.duration)

        SentrySDK.logger.info(
            "MetricKit CPU stressor started",
            attributes: [
                "stressor": "cpu",
                "duration_seconds": Self.duration,
                "worker_count": workerCount
            ]
        )

        for _ in 0..<workerCount {
            group.enter()
            queue.async {
                defer { group.leave() }
                self.consumeCPU(until: endTime)
            }
        }

        group.notify(queue: queue) {
            self.lock.lock()
            self.running = false
            self.lock.unlock()

            SentrySDK.logger.info(
                "MetricKit CPU stressor completed",
                attributes: [
                    "stressor": "cpu",
                    "duration_seconds": Self.duration,
                    "worker_count": workerCount
                ]
            )
        }
    }

    private func consumeCPU(until endTime: Date) {
        var result = 0.0

        while Date() < endTime {
            for value in 1...100_000 {
                let input = Double(value)
                result += sin(input) * cos(input)
            }

            if result.isInfinite {
                print(result)
            }
        }
    }
}

private final class MetricKitDiskWriteStressor {
    private static let payloadSize = 16 * 1_024 * 1_024
    private static let targetBytesWritten = 2 * 1_024 * 1_024 * 1_024

    private let queue = DispatchQueue(label: "io.sentry.sample.metrickit.disk-write")
    private let payload = Data(repeating: 0xA5, count: MetricKitDiskWriteStressor.payloadSize)
    private let fileURL: URL
    private let lock = NSLock()
    private var running = false

    init() {
        // swiftlint:disable:next force_unwrapping
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        fileURL = cachesDirectory
            .appendingPathComponent("MetricKitDiskWriteStressor", isDirectory: true)
            .appendingPathComponent("payload.bin")
    }

    func start() {
        lock.lock()
        guard !running else {
            lock.unlock()
            SentrySDK.logger.warn(
                "MetricKit disk-write stressor already running",
                attributes: ["stressor": "disk_write"]
            )
            return
        }
        running = true
        lock.unlock()

        SentrySDK.logger.info(
            "MetricKit disk-write stressor started",
            attributes: [
                "stressor": "disk_write",
                "payload_size_bytes": Self.payloadSize,
                "target_bytes_written": Self.targetBytesWritten
            ]
        )

        queue.async { [self] in
            writePayload()
        }
    }

    private func writePayload() {
        defer {
            lock.lock()
            running = false
            lock.unlock()
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var bytesWritten = 0
            while bytesWritten < Self.targetBytesWritten {
                try payload.write(to: fileURL, options: .atomic)
                bytesWritten += payload.count
            }

            SentrySDK.logger.info(
                "MetricKit disk-write stressor completed",
                attributes: [
                    "stressor": "disk_write",
                    "bytes_written": bytesWritten
                ]
            )
        } catch {
            SentrySDK.logger.error(
                "MetricKit disk-write stressor failed",
                attributes: [
                    "stressor": "disk_write",
                    "error": error.localizedDescription
                ]
            )
            SentrySDK.capture(error: error)
        }
    }
}

private final class MetricKitHangStressor {
    func start(workload: String, operation: () throws -> Int) {
        SentrySDK.logger.info(
            "MetricKit hang stressor started",
            attributes: ["stressor": "hang", "workload": workload]
        )

        // Run all four batches synchronously on the main thread for one continuous ~4 second hang.
        let startTime = ProcessInfo.processInfo.systemUptime
        do {
            var checksum = 0
            for _ in 0..<4 {
                checksum &+= try operation()
            }
            SentrySDK.logger.info(
                "MetricKit hang stressor completed",
                attributes: [
                    "stressor": "hang",
                    "workload": workload,
                    "duration_seconds": ProcessInfo.processInfo.systemUptime - startTime,
                    "checksum": checksum
                ]
            )
        } catch {
            SentrySDK.logger.error(
                "MetricKit hang stressor failed",
                attributes: ["stressor": "hang", "workload": workload, "error": error.localizedDescription]
            )
        }
    }
}

private struct MetricKitProduct: Codable {
    let name: String
    let price: Double
}

// Keep service frames in optimized builds. Each leaf does real CPU work for ~250 ms rather
// than sleeping or funneling every sample into a shared busy-wait function.
private final class MetricKitCatalogService {
    private let serialization = MetricKitSerializationService()
    private let pricing = MetricKitPricingService()
    private let search = MetricKitSearchService()

    @inline(never)
    func refreshCatalog() throws -> Int {
        let products = try serialization.decodeProducts()
        let total = pricing.calculateTotal(products)
        let index = search.buildIndex(products)
        let matches = search.rankProducts(products)
        return Int(total) + index.count + matches.count
    }
}

private final class MetricKitCheckoutService {
    private let serialization = MetricKitSerializationService()
    private let pricing = MetricKitPricingService()

    @inline(never)
    func checkout() throws -> Int {
        let products = try serialization.decodeProducts()
        let total = pricing.calculateTotal(products)
        let shipping = calculateShipping(products)
        let receipt = try serialization.encodeReceipt(products)
        return Int(total + shipping) + receipt.count
    }

    @inline(never)
    private func calculateShipping(_ products: [MetricKitProduct]) -> Double {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        var shipping = 0.0
        repeat {
            for zone in 1...100 {
                shipping = products.reduce(0) { $0 + sqrt($1.price * Double(zone)) }
            }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return shipping
    }
}

private final class MetricKitSerializationService {
    private let payload = Data(
        ("[" + (0..<200).map { "{\"name\":\"Product \($0)\",\"price\":\($0 + 1)}" }.joined(separator: ",") + "]").utf8
    )

    @inline(never)
    func decodeProducts() throws -> [MetricKitProduct] {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        let decoder = JSONDecoder()
        var products: [MetricKitProduct]
        repeat {
            products = try decoder.decode([MetricKitProduct].self, from: payload)
        } while ProcessInfo.processInfo.systemUptime < deadline
        return products
    }

    @inline(never)
    func encodeReceipt(_ products: [MetricKitProduct]) throws -> Data {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var receipt: Data
        repeat {
            receipt = try encoder.encode(products)
        } while ProcessInfo.processInfo.systemUptime < deadline
        return receipt
    }
}

private final class MetricKitPricingService {
    @inline(never)
    func calculateTotal(_ products: [MetricKitProduct]) -> Double {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        var total = 0.0
        repeat {
            for discount in 1...100 {
                total = products.reduce(0) { $0 + ($1.price * (1 - Double(discount) / 1_000)).rounded() }
            }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return total
    }
}

private final class MetricKitSearchService {
    @inline(never)
    func buildIndex(_ products: [MetricKitProduct]) -> [String: [Int]] {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        var index: [String: [Int]]
        repeat {
            index = [:]
            for (productID, product) in products.enumerated() {
                for word in product.name.lowercased().split(separator: " ") {
                    index[String(word), default: []].append(productID)
                }
            }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return index
    }

    @inline(never)
    func rankProducts(_ products: [MetricKitProduct]) -> [MetricKitProduct] {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.25
        var ranked: [MetricKitProduct]
        repeat {
            ranked = products.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return ranked
    }
}
