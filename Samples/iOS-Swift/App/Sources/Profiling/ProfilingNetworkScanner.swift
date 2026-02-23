import UIKit

class ProfilingNetworkScanner: NSObject {
    var shouldPerformNetworkWork = false
    let urlSession = URLSession(configuration: .ephemeral)
    var tasks = [URLSessionTask]()
    let concurrentNetworkRequests = 20
    lazy var defaultStartingIP = rangeStarts.first!
    lazy var currentIP = defaultStartingIP
    var responses = [String: NSMutableArray]()

    lazy var networkScanOperationQueue: OperationQueue = {
        let oq = OperationQueue()
        oq.maxConcurrentOperationCount = concurrentNetworkRequests
        oq.qualityOfService = .userInitiated
        oq.isSuspended = false
        return oq
    }()

    lazy var ipSyncOQ: OperationQueue = {
        let oq = OperationQueue()
        oq.maxConcurrentOperationCount = 1
        oq.qualityOfService = .userInteractive
        oq.isSuspended = false
        return oq
    }()

    func start() {
        shouldPerformNetworkWork = true
        for _ in 0 ..< concurrentNetworkRequests {
            launchTask(ip: currentIP)
            currentIP = increment(ip: currentIP)!
        }
    }

    func end() {
        shouldPerformNetworkWork = false
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        networkScanOperationQueue.cancelAllOperations()
        print("results: %@", responses)
    }

    func compare(ipa: String, ipb: String) -> ComparisonResult {
        guard ipa != ipb else { return .orderedSame }

        let a = ipa.components(separatedBy: ".").map { ($0 as NSString).integerValue }
        let b = ipb.components(separatedBy: ".").map { ($0 as NSString).integerValue }

        func _compare(index: Int) -> ComparisonResult {
            if b[index] > a[index] {
                return .orderedAscending
            } else if b[index] < a[index] {
                return .orderedDescending
            } else {
                if index == 3 {
                    return .orderedSame
                } else {
                    return _compare(index: index + 1)
                }
            }
        }

        return _compare(index: 0)
    }

    func ipInRange(ip: String, min: String, max: String) -> Bool {
        guard ip != min && ip != max else { return true }
        let a = compare(ipa: ip, ipb: min)
        if a == .orderedAscending {
            return false
        }
        let b = compare(ipa: ip, ipb: max)
        if b == .orderedDescending {
            return false
        }

        return true
    }

    let publicIPRanges = [
        "1.0.0.0": "9.255.255.255",
        "11.0.0.0": "126.255.255.255",
        "129.0.0.0": "169.253.255.255",
        "169.255.0.0": "172.15.255.255",
        "172.32.0.0": "191.0.1.255",
        "192.0.3.0": "192.88.98.255",
        "192.88.100.0": "192.167.255.255",
        "192.169.0.0": "198.17.255.255",
        "198.20.0.0": "223.255.255.255"
    ]

    lazy var rangeStarts = publicIPRanges.keys.sorted(by: { a, b in
        return compare(ipa: a, ipb: b) != .orderedDescending
    })

    func increment(ip: String) -> String? {
        var components = ip.components(separatedBy: ".").map { ($0 as NSString).integerValue }
        func _increment(index: Int) -> Bool {
            components[index] += 1
            if components[index] > 255 {
                if index == 0 {
                    return false
                }
                components[index] = 0
                return _increment(index: index - 1)
            }
            return true
        }

        if !_increment(index: 3) {
            return nil
        }

        let nextIP = components.map { String($0) }.joined(separator: ".")

        guard let _ = publicIPRanges.first(where: { pair in
            ipInRange(ip: nextIP, min: pair.key, max: pair.value)
        }) else {
            if let nextRange = publicIPRanges.first(where: {
                compare(ipa: nextIP, ipb: $0.key) == .orderedAscending
            }) {
                return nextRange.key
            } else {
                return nil
            }
        }

        return nextIP
    }

    func launchTask(ip: String) {
        print("dispatching task to send request to \(ip)")
        networkScanOperationQueue.addOperation {
            if !self.shouldPerformNetworkWork { return }
            print("starting request to \(ip)")
            var request = URLRequest(url: URL(string: "https://\(ip)")!, timeoutInterval: 1.0)
            request.httpMethod = "HEAD"
            let task = self.urlSession.dataTask(with: request) { _, _, error in
//                print("response from \(ip): \(error != nil ? " \(error!.localizedDescription)" : String((response as! HTTPURLResponse).statusCode))")
                if let error = error {
                    var key = error.localizedDescription
                    if key.count > 50 {
                        key = (key as NSString).substring(to: 50)
                    }
                    if self.responses[key] == nil {
                        self.responses[key] = NSMutableArray(object: ip)
                    } else {
                        self.responses[key]!.add(ip)
                    }
                }
                self.ipSyncOQ.addOperation {
                    if self.shouldPerformNetworkWork {
                        if let nextIP = self.increment(ip: self.currentIP) {
                            self.currentIP = nextIP
                            self.launchTask(ip: nextIP)
                        } else {
                            self.currentIP = self.defaultStartingIP
                            self.launchTask(ip: self.currentIP)
                        }
                    }
                }
            }
            task.resume()
            self.tasks.append(task)
        }
    }
}
