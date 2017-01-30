//
//  Register.swift
//  Sentry
//
//  Created by Daniel Griesser on 24/01/2017.
//
//

import Foundation

@objc(SentryRegister) public final class Register: NSObject {
    public var registers: [String: String] = [:]
    
    @objc public init?(registerDict: [String: AnyObject]?) {
        guard let registerDict = registerDict else { return nil }
        for (registerKey, registerValues) in registerDict {
            if let registerValues = registerValues as? [String: AnyObject] {
                if registerKey == "basic" { // Swift3: remove -> if let where
                    for (key, value) in registerValues {
                        if let memoryAddress = MemoryAddress(value)?.asHex() {
                            registers[key] = memoryAddress
                        }
                    }
                }
            }
        }
    }
    
}
