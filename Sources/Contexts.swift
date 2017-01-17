//
//  Context.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/8/16.
//
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#endif

import KSCrash

// A class used to represent an exception: `sentry.interfaces.exception`
final class Contexts {}

extension Contexts: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [
            "os": OSContext().serialized,
            "device": DeviceContext().serialized
        ]
    }
}

private final class OSContext {
    
    var info = KSCrash.sharedInstance().systemInfo
    
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

private final class DeviceContext {
    
    var info = KSCrash.sharedInstance().systemInfo
    
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
        } else {
            
            #if os(OSX)
                return info?["model"] as? String
            #else
                // Reversed for iOS
                return info?["machine"] as? String
            #endif
        }
    }
    
    var modelDetail: String? {
        if isSimulator {
            return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        } else {
            return info?["model"] as? String
        }
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
        guard let model = model else { return nil }
        
        let pattern = "^\\D+"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = model as NSString
            // swiftlint:disable legacy_constructor
            #if swift(>=3.0)
                let results = regex.matches(in: model,
                options: [], range: NSMakeRange(0, nsString.length))
                return results.map { nsString.substring(with: $0.range)}.first
            #else
                let results = regex.matchesInString(model,
                                                    options: [], range: NSMakeRange(0, nsString.length))
                return results.map { nsString.substringWithRange($0.range)}.first
            #endif
            // swiftlint:enable legacy_constructor
        } catch let error as NSError {
            Log.Error.log("Invalid family regeex: \(error.localizedDescription)")
            return nil
        }
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
        attributes.append(("freeMemory", freeMemory))
        attributes.append(("memorySize", memorySize))
        attributes.append(("usableMemory", usableMemory))
        attributes.append(("storageSize", storageSize))
        
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
