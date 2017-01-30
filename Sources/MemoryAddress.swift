//
//  MemoryAddress.swift
//  Sentry
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

struct MemoryAddress {
    
    private let hex: String
    private let int: UInt64
    
    static private func asMemoryAddress(_ object: AnyObject?) -> UInt64? {
        guard let object = object else { return nil }
        if let number = object as? NSNumber {
            #if swift(>=3.0)
                return number.uint64Value
            #else
                return number.unsignedLongLongValue
            #endif
        }
        return nil
    }
    
    init?(_ object: AnyObject?) {
        guard let int = MemoryAddress.asMemoryAddress(object) else { return nil }
        self.int = int
        self.hex = String(format: "0x%x", int)
    }
    
    func asInt() -> UInt64 {
        return int
    }
    
    func asHex() -> String {
        return hex
    }
    
}
