import Foundation

struct IOSSimulatorSelection {
    let device: IOSSimulatorDevice
    let xcodebuildDestination: String
}

struct IOSSimulatorDevice {
    let name: String
    let udid: String
    let state: String
    let runtimeIdentifier: String
    let runtimeVersion: [Int]

    var runtimeDescription: String {
        guard let range = runtimeIdentifier.range(of: "iOS-") else {
            return runtimeIdentifier.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        }
        return "iOS " + runtimeIdentifier[range.upperBound...].replacingOccurrences(of: "-", with: ".")
    }
}

final class IOSSimulatorResolver {
    private struct SimctlDeviceList: Decodable {
        let devices: [String: [RawDevice]]
    }

    private struct RawDevice: Decodable {
        let name: String
        let udid: String
        let state: String
        let isAvailable: Bool?
    }

    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func resolve(deviceID requestedDeviceID: String?, destination requestedDestination: String?) throws -> IOSSimulatorSelection {
        let devices = try availableIOSDevices()
        guard !devices.isEmpty else {
            try fail("No available iOS simulator devices found.")
        }

        let destinationParts = parseDestination(requestedDestination)
        if let destinationID = destinationParts["id"] {
            let device = try deviceWithUDID(destinationID, in: devices)
            return IOSSimulatorSelection(device: device, xcodebuildDestination: "id=\(device.udid)")
        }

        if let requestedDeviceID, requestedDeviceID != "booted" {
            let device = try deviceWithUDID(requestedDeviceID, in: devices)
            return IOSSimulatorSelection(device: device, xcodebuildDestination: "id=\(device.udid)")
        }

        let requestedName = destinationParts["name"]
        let requestedOS = destinationParts["OS"]

        if let booted = preferredDevice(in: devices, state: "Booted", name: requestedName, os: requestedOS) {
            return IOSSimulatorSelection(device: booted, xcodebuildDestination: "id=\(booted.udid)")
        }

        if let requestedDeviceID, requestedDeviceID == "booted" {
            try fail("--ios-device-id booted was requested, but no matching booted iOS simulator was found.")
        }

        if let selected = preferredDevice(in: devices, state: nil, name: requestedName, os: requestedOS)
            ?? preferredDevice(in: devices, state: nil, name: nil, os: nil) {
            return IOSSimulatorSelection(device: selected, xcodebuildDestination: "id=\(selected.udid)")
        }

        try fail("No matching iOS simulator found for destination: \(requestedDestination ?? "auto")")
    }

    private func availableIOSDevices() throws -> [IOSSimulatorDevice] {
        let output = try processRunner.runOutput("xcrun", ["simctl", "list", "devices", "available", "-j"])
        let data = Data(output.utf8)
        let list = try JSONDecoder().decode(SimctlDeviceList.self, from: data)

        return list.devices.flatMap { runtimeIdentifier, rawDevices -> [IOSSimulatorDevice] in
            guard runtimeIdentifier.contains(".iOS-") else { return [] }
            let version = runtimeVersion(from: runtimeIdentifier)
            return rawDevices.compactMap { rawDevice in
                guard rawDevice.isAvailable != false else { return nil }
                guard rawDevice.name.hasPrefix("iPhone") else { return nil }
                return IOSSimulatorDevice(
                    name: rawDevice.name,
                    udid: rawDevice.udid,
                    state: rawDevice.state,
                    runtimeIdentifier: runtimeIdentifier,
                    runtimeVersion: version
                )
            }
        }
    }

    private func deviceWithUDID(_ udid: String, in devices: [IOSSimulatorDevice]) throws -> IOSSimulatorDevice {
        guard let device = devices.first(where: { $0.udid == udid }) else {
            try fail("Requested iOS simulator device not found or unavailable: \(udid)")
        }
        return device
    }

    private func preferredDevice(in devices: [IOSSimulatorDevice], state: String?, name: String?, os: String?) -> IOSSimulatorDevice? {
        let matching = devices.filter { device in
            if let state, device.state != state { return false }
            if let name, device.name != name { return false }
            if let os, os != "latest", !runtimeMatches(device.runtimeVersion, os: os) { return false }
            return true
        }

        return matching.sorted { lhs, rhs in
            let lhsScore = preferenceScore(lhs)
            let rhsScore = preferenceScore(rhs)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            if lhs.runtimeVersion != rhs.runtimeVersion { return lhs.runtimeVersion.lexicographicallyPrecedes(rhs.runtimeVersion) == false }
            return lhs.name < rhs.name
        }.first
    }

    private func preferenceScore(_ device: IOSSimulatorDevice) -> Int {
        switch device.name {
        case "iPhone 16 Pro": return 100
        case "iPhone 17 Pro": return 90
        case let name where name.contains("Pro"): return 80
        default: return 50
        }
    }

    private func runtimeMatches(_ version: [Int], os: String) -> Bool {
        let requested = os.split(separator: ".").compactMap { Int($0) }
        guard !requested.isEmpty else { return true }
        return zip(version, requested).allSatisfy(==)
    }

    private func runtimeVersion(from identifier: String) -> [Int] {
        guard let range = identifier.range(of: "iOS-") else { return [] }
        return identifier[range.upperBound...]
            .split(separator: "-")
            .compactMap { Int($0) }
    }

    private func parseDestination(_ destination: String?) -> [String: String] {
        guard let destination else { return [:] }
        var result: [String: String] = [:]
        for part in destination.split(separator: ",") {
            let pieces = part.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pieces.count == 2 else { continue }
            result[pieces[0]] = pieces[1]
        }
        return result
    }
}
