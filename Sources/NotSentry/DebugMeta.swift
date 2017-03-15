//
//  DebugMeta.swift
//  Sentry
//
//  Created by Josh Holtz on 7/26/16.
//
//

import Foundation

// A class used to represent an exception: `debug_meta`
final class DebugMeta {
    let images: [BinaryImage]
    
    init(binaryImages: [BinaryImage]) {
        self.images = binaryImages
    }
    
}

extension DebugMeta: EventSerializable {
    internal typealias SerializedType = SerializedTypeDictionary
    internal var serialized: SerializedType {
        return [
            "images": images.map({ $0.serialized })
        ]
    }
}
