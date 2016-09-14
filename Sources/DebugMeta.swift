//
//  DebugMeta.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/26/16.
//
//

import Foundation

// A class used to represent an exception: `debug_meta`
@objc internal class DebugMeta: NSObject {
	
	let images: [BinaryImage]
	
	init(binaryImages: [BinaryImage]) {
		self.images = binaryImages
		super.init()
	}
	
}

extension DebugMeta: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return [
			"images": images.map({$0.serialized})
		]
	}
}

@objc internal class BinaryImage: NSObject {
	
	internal typealias MemoryAddress = UInt64
	
	var type: String?
	var cpuSubtype: Int?
	var uuid: String?
	var imageVMAddress: MemoryAddress?
	var imageAddress: MemoryAddress?
	var cpuType: Int?
	var imageSize: Int?
	var name: String?
	
	internal convenience init?(appleCrashBinaryImagesDict: [String: AnyObject]) {
		self.init()
		
		self.type = "apple"
		self.cpuSubtype = appleCrashBinaryImagesDict["cpu_subtype"] as? Int
		self.uuid = appleCrashBinaryImagesDict["uuid"] as? String
		self.imageVMAddress = BinaryImage.asMemoryAddress(appleCrashBinaryImagesDict["image_vmaddr"])
		self.imageAddress = BinaryImage.asMemoryAddress(appleCrashBinaryImagesDict["image_addr"])
		self.cpuType = appleCrashBinaryImagesDict["cpu_type"] as? Int
		self.imageSize = appleCrashBinaryImagesDict["image_size"] as? Int
		self.name = appleCrashBinaryImagesDict["name"] as? String
	}
	
	internal class func getBinaryImage(_ binaryImages: [BinaryImage], address: MemoryAddress) -> BinaryImage? {
		for binaryImage in binaryImages {
			if let imageStart = binaryImage.imageAddress,
				let imageSize = binaryImage.imageSize {
				
				let imageEnd = imageStart + UInt64(imageSize)
				if address >= imageStart && address < imageEnd {
					return binaryImage
				}
				
			}
		}
		
		return nil
	}
	
	internal class func asMemoryAddress(_ object: AnyObject?) -> MemoryAddress? {
		guard let object = object else { return nil }
		
		switch object {
		case let object as NSNumber:
			#if swift(>=3.0)
				return object.uint64Value
			#else
				return object.unsignedLongLongValue
			#endif
		case let object as Int64:
			return UInt64(object)
		default:
			return nil
		}
	}
	
	internal class func getHexAddress(_ object: AnyObject?) -> String? {
		return getHexAddress(asMemoryAddress(object))
	}
	
	internal class func getHexAddress(_ address: MemoryAddress?) -> String? {
		guard let address = address else { return nil }
		return String(format: "0x%x", address)
	}
}

extension BinaryImage: EventSerializable {
	internal typealias SerializedType = SerializedTypeDictionary
	internal var serialized: SerializedType {
		return SerializedType()
		.set("type", value: type)
		.set("cpu_subtype", value: cpuSubtype)
		.set("uuid", value: uuid)
		.set("image_vmaddr", value: BinaryImage.getHexAddress(imageVMAddress))
		.set("image_addr", value: BinaryImage.getHexAddress(imageAddress))
		.set("cpu_type", value: cpuType)
		.set("image_size", value: imageSize)
		.set("name", value: name)
	}
}
