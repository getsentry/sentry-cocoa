//
//  BinaryImage.swift
//  Sentry
//
//  Created by Daniel Griesser on 12/12/2016.
//
//

import Foundation

final class BinaryImage {
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
        self.imageVMAddress = MemoryAddress(appleCrashBinaryImagesDict["image_vmaddr"])
        self.imageAddress = MemoryAddress(appleCrashBinaryImagesDict["image_addr"])
        self.cpuType = appleCrashBinaryImagesDict["cpu_type"] as? Int
        self.imageSize = appleCrashBinaryImagesDict["image_size"] as? Int
        self.name = appleCrashBinaryImagesDict["name"] as? String
        self.majorVersion = appleCrashBinaryImagesDict["major_version"] as? Int
        self.minorVersion = appleCrashBinaryImagesDict["minor_version"] as? Int
        self.revisionVersion = appleCrashBinaryImagesDict["revision_version"] as? Int
    }
    
    internal class func getBinaryImage(_ binaryImages: [BinaryImage], address: MemoryAddress) -> BinaryImage? {
        for binaryImage in binaryImages {
            if let imageStart = binaryImage.imageAddress?.asInt(),
                let imageSize = binaryImage.imageSize {
                
                let imageEnd = imageStart + UInt(imageSize)
                if address.asInt() >= imageStart && address.asInt() < imageEnd {
                    return binaryImage
                }
            }
        }
        
        return nil
    }

}

extension BinaryImage: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        var attributes: [Attribute] = []
        
        attributes.append(("type", type))
        attributes.append(("cpu_subtype", cpuSubtype))
        attributes.append(("uuid", uuid))
        attributes.append(("image_vmaddr", imageVMAddress?.asHex()))
        attributes.append(("image_addr", imageAddress?.asHex()))
        attributes.append(("cpu_type", cpuType))
        attributes.append(("image_size", imageSize))
        attributes.append(("name", name))
        attributes.append(("major_version", majorVersion))
        attributes.append(("minor_version", minorVersion))
        attributes.append(("revision_version", revisionVersion))
        
        return convertAttributes(attributes)
    }
}
