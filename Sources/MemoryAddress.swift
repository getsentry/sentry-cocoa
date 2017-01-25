//
//  MemoryAddress.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

import Foundation

struct MemoryAddress {
    
    private let hex: String
    private let int: UInt64
    
    static private func asMemoryAddress(_ object: AnyObject?) -> UInt64? {
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
    
    static private func getHexAddress(_ address: UInt64?) -> String? {
        guard let address = address else { return nil }
        return String(format: "0x%x", address)
    }
    
    init?(_ object: AnyObject?) {
        guard let int = MemoryAddress.asMemoryAddress(object) else { return nil }
        self.int = int
        
        guard let hex = MemoryAddress.getHexAddress(int) else { return nil }
        self.hex = hex
    }
    
    func asInt() -> UInt64 {
        return int
    }
    
    func asHex() -> String {
        return hex
    }
    
}
