//
//  DebugMeta.swift
//  SentrySwift
//
//  Created by Josh Holtz on 7/26/16.
//
//

import Foundation

// A class used to represent an exception: `debug_meta`
@objc internal final class DebugMeta: NSObject {
    
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
