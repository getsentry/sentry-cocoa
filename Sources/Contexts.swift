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
@objc public final class Contexts: NSObject {
    
}

extension Contexts: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [
            "os": OSContext().serialized,
            "device": DeviceContext().serialized
        ]
    }
}

private class OSContext: NSObject {
    
    var info = KSSystemInfo.systemInfo()
    
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
        return info?[KSSystemField_SystemVersion] as? String
    }
    
    var build: String? {
        return info?[KSSystemField_OSVersion] as? String
    }
    
    var kernelVersion: String? {
        return info?[KSSystemField_KernelVersion] as? String
    }
    
    var jailbroken: String? {
        return info?[KSSystemField_Jailbroken] as? String
    }
}

extension OSContext: EventSerializable {
    typealias SerializedType = SerializedTypeDictionary
    var serialized: SerializedType {
        return [:]
            .set("name", value: name)
            .set("version", value: version)
            .set("build", value: build)
            .set("kernel_version", value: kernelVersion)
            .set("rooted", value: jailbroken)
    }
}

private class DeviceContext: NSObject {
    
    var info = KSSystemInfo.systemInfo()
    
    var architecture: String? {
        return info?[KSSystemField_CPUArch] as? String
    }
    
    var family: String? {
        return extractFamily(model)
    }
    
    var machine: String? {
        #if os(OSX)
            return info?[KSSystemField_Machine] as? String
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
                return info?[KSSystemField_Model] as? String
            #else
                // Reversed for iOS
                return info?[KSSystemField_Machine] as? String
            #endif
        }
    }
    
    var modelDetail: String? {
        if isSimulator {
            return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
        } else {
            return info?[KSSystemField_Model] as? String
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
            SentryLog.Error.log("Invalid family regeex: \(error.localizedDescription)")
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
