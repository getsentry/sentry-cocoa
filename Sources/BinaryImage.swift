//
//  BinaryImage.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 12/12/2016.
//
//

import Foundation

final class BinaryImage {
    
    internal typealias MemoryAddress = UInt64
    
    var type: String?
    var cpuSubtype: Int?
    var uuid: String?
    var imageVMAddress: MemoryAddress?
    var imageAddress: MemoryAddress?
    var cpuType: Int?
    var imageSize: Int?
    var name: String?
    var majorVersion: Int?
    var minorVersion: Int?
    var revisionVersion: Int?
    
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
        self.majorVersion = appleCrashBinaryImagesDict["major_version"] as? Int
        self.minorVersion = appleCrashBinaryImagesDict["minor_version"] as? Int
        self.revisionVersion = appleCrashBinaryImagesDict["revision_version"] as? Int
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
        var attributes: [Attribute] = []
        
        attributes.append(("type", type))
        attributes.append(("cpu_subtype", cpuSubtype))
        attributes.append(("uuid", uuid))
        attributes.append(("image_vmaddr", BinaryImage.getHexAddress(imageVMAddress)))
        attributes.append(("image_addr", BinaryImage.getHexAddress(imageAddress)))
        attributes.append(("cpu_type", cpuType))
        attributes.append(("image_size", imageSize))
        attributes.append(("name", name))
        attributes.append(("major_version", majorVersion))
        attributes.append(("minor_version", minorVersion))
        attributes.append(("revision_version", revisionVersion))
        
        return convertAttributes(attributes)
    }
}
