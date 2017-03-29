//
//  Context.swift
//  Sentry
//
//  Created by Josh Holtz on 7/8/16.
//
//

import Foundation
import KSCrash
#if os(iOS) || os(tvOS)
    import UIKit
#endif

#if swift(>=3.0)
internal typealias SystemInfo = [AnyHashable: AnyType]
#else
internal typealias SystemInfo = [NSObject: AnyObject]
#endif

protocol Context {
    var info: SystemInfo? { get set }
    init(_ info: SystemInfo?)
    init()
}

extension Context {
    init(_ info: SystemInfo?) {
        self.init()
        self.info = info
    }
}

internal struct Contexts {}

extension Contexts: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        let info = KSCrash.sharedInstance().systemInfo
        return [
            "os": OSContext(info).serialized,
            "device": DeviceContext(info).serialized,
            "app": AppContext(info).serialized
        ]
    }
}

private struct OSContext: Context {
    var info: SystemInfo?
    
    var name: String? {
        #if os(iOS)
            return "iOS"
        #elseif os(tvOS)
            return "tvOS"
        #elseif os(OSX)
            return "macOS"
        #elseif os(watchOS)
            return "watchOS"
        #else
            return nil
        #endif
    }
    
    var version: String? {
        return info?["systemVersion"] as? String
    }
    
    var build: String? {
        return info?["osVersion"] as? String
    }

    var kernelVersion: String? {
        return info?["kernelVersion"] as? String
    }
    
    var jailbroken: String? {
        return info?["isJailbroken"] as? String
    }
}

extension OSContext: EventSerializable {
    typealias SerializedType = SerializedTypeDictionary
    
    var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("name", name))
        attributes.append(("version", version))
        attributes.append(("build", build))
        attributes.append(("kernel_version", kernelVersion))
        attributes.append(("rooted", jailbroken))
        
        return convertAttributes(attributes)
    }
}

private struct DeviceContext: Context {
    var info: SystemInfo?
    
    var architecture: String? {
        return info?["cpuArchitecture"] as? String
    }
    
    var family: String? {
        return extractFamily(model)
    }
    
    var freeMemory: Int? {
        return info?["freeMemory"] as? Int
    }
    
    var memorySize: Int? {
        return info?["memorySize"] as? Int
    }
    
    var usableMemory: Int? {
        return info?["usableMemory"] as? Int
    }
    
    var storageSize: Int? {
        return info?["storageSize"] as? Int
    }
    
    var bootTime: String? {
        return info?["bootTime"] as? String
    }
    
    var timezone: String? {
        return info?["timezone"] as? String
    }
    
    var machine: String? {
        #if os(OSX)
            return info?["machine"] as? String
        #else
            // Not needed for iOS
            return nil
        #endif
    }
    
    var model: String? {
        if isSimulator {
            return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        }
        #if os(OSX)
            return info?["model"] as? String
        #else
            // Reversed for iOS
            return info?["machine"] as? String
        #endif
    }
    
    var modelDetail: String? {
        if isSimulator {
            return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        }
        return info?["model"] as? String
    }
    
    var isOSX: Bool {
        #if os(OSX)
            return true
        #else
            return false
        #endif
    }
    
    var isSimulator: Bool {
        #if (arch(i386) || arch(x86_64)) && (os(iOS) || os(watchOS) || os(tvOS))
            return true
        #else
            return false
        #endif
    }
    
    private func extractFamily(_ model: String?) -> String? {
        let pattern = "^\\D+"
        guard let model = model, let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = model as NSString
        // swiftlint:disable legacy_constructor
        #if swift(>=3.0)
            let results = regex.matches(in: model,
                                        options: [], range: NSMakeRange(0, nsString.length))
            return results.map { nsString.substring(with: $0.range) }.first
        #else
            let results = regex.matchesInString(model,
            options: [], range: NSMakeRange(0, nsString.length))
            return results.map { nsString.substringWithRange($0.range) }.first
        #endif
        // swiftlint:enable legacy_constructor
    }
}

extension DeviceContext: EventSerializable {
    typealias SerializedType = SerializedTypeDictionary
    
    var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("family", family))
        attributes.append(("arch", architecture))
        attributes.append(("model", model))
        attributes.append(("family", family))
        attributes.append(("free_memory", freeMemory))
        attributes.append(("memory_size", memorySize))
        attributes.append(("usable_memory", usableMemory))
        attributes.append(("storage_size", storageSize))
        attributes.append(("boot_time", bootTime))
        attributes.append(("timezone", timezone))
        
        switch (isOSX, isSimulator) {
        // macOS
        case (true, _):
            attributes.append(("model", machine))
        // iOS/tvOS/watchOS Sim
        case (false, true):
            attributes.append(("simulator", isSimulator))
        // iOS/tvOS/watchOS Device
        default:
            attributes.append(("model_id", modelDetail))
            attributes.append(("simulator", isSimulator))
        }
        
        return convertAttributes(attributes)
    }
}

private struct AppContext: Context {
    var info: SystemInfo?
    
    var appStartTime: String? {
        return info?["appStartTime"] as? String
    }
    
    var appID: String? {
        return info?["appID"] as? String
    }
    
    var deviceAppHash: String? {
        return info?["deviceAppHash"] as? String
    }
    
    var buildType: String? {
        return info?["buildType"] as? String
    }
    
    var bundleID: String? {
        return info?["bundleID"] as? String
    }
    
    var bundleName: String? {
        return info?["bundleName"] as? String
    }
    
    var bundleVersion: String? {
        return info?["bundleVersion"] as? String
    }
    
    var bundleShortVersion: String? {
        return info?["bundleShortVersion"] as? String
    }
    
}

extension AppContext: EventSerializable {
    typealias SerializedType = SerializedTypeDictionary
    
    var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("app_start_time", appStartTime))
        attributes.append(("device_app_hash", deviceAppHash))
        attributes.append(("app_id", appID))
        attributes.append(("build_type", buildType))
        attributes.append(("app_identifier", bundleID))
        attributes.append(("app_name", bundleName))
        attributes.append(("app_build", bundleVersion))
        attributes.append(("app_version", bundleShortVersion))
        
        return convertAttributes(attributes)
    }
}
