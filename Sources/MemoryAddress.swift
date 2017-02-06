//
//  MemoryAddress.swift
//  Sentry
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

struct MemoryAddress {
    
    private let hex: String
    private let int: UInt
    
    static private func asMemoryAddress(_ object: AnyObject?) -> UInt? {
        guard let object = object else { return nil }
        if let number = object as? NSNumber {
            #if swift(>=3.0)
                return number.uintValue
            #else
                return number.unsignedIntegerValue
            #endif
        }
        return nil
    }
    
    init?(_ object: AnyObject?) {
        guard let int = MemoryAddress.asMemoryAddress(object) else { return nil }
        self.int = int
        self.hex = "0x\(String(int, radix: 16))"
    }
    
    init?(_ string: String?) {
        guard let hex = string else { return nil }
        guard hex.hasPrefix("0x") else { return nil }
        guard let int = Int(String(hex.characters.dropFirst(2)), radix: 16) else { return nil }
        self.int = UInt(int)
        self.hex = hex
    }
    
    func asInt() -> UInt {
        return int
    }
    
    func asHex() -> String {
        return hex
    }
    
}
