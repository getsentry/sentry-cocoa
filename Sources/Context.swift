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

import KSCrash.KSSystemInfo

// A class used to represent an exception: `sentry.interfaces.exception`
@objc public class Context: NSObject {

}

extension Context: EventSerializable {
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
		return info?[KSSystemField_OSVersion] as? String
	}
	
	var version: String? {
		return info?[KSSystemField_OSVersion] as? String
	}
	
	var build: String? {
		return info?[KSSystemField_SystemVersion] as? String
	}
	
	var kernalVersion: String? {
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
			.set("kernalVersion", value: kernalVersion)
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
		if let simModel = NSProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] where isSimulator {
			return simModel
		} else {
		
			#if os(OSX)
				return info?[KSSystemField_Model] as? String
			#else
				// Reversed for iOS
				return info?[KSSystemField_Machine] as? String
			#endif
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
	
	private func extractFamily(model: String?) -> String? {
		guard let model = model else { return nil }
		
		let pattern = "^\\D+"
	
		do {
			let regex = try NSRegularExpression(pattern: pattern, options: [])
			let nsString = model as NSString
			let results = regex.matchesInString(model,
			                                    options: [], range: NSMakeRange(0, nsString.length))
			return results.map { nsString.substringWithRange($0.range)}.first
		} catch let error as NSError {
			SentryLog.Error.log("Invalid family regeex: \(error.localizedDescription)")
			return nil
		}
	}
}

extension DeviceContext: EventSerializable {
	typealias SerializedType = SerializedTypeDictionary
	var serialized: SerializedType {
		var dict = SerializedType()
			.set("family", value: family)
			.set("architecture", value: architecture)
			.set("model", value: model)
			.set("family", value: family)
		
		switch (isOSX, isSimulator) {
		// macOS
		case (true, _):
			dict = dict.set("machine", value: machine)
			
		// iOS/tvOS/watchOS Sim
		case (false, true):
			dict = dict
				.set("simulator", value: isSimulator)
			
		// iOS/tvOS/watchOS Device
		default:
			dict = dict
				.set("model_id", value: model)
				.set("simulator", value: isSimulator)
		}
		
		return dict
	}
}