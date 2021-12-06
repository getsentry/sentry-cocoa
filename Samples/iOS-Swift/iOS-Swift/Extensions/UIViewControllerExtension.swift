//
//  UIViewControllerExtension.swift
//  iOS-Swift
//
//  Created by Dhiogo Brustolin on 06/12/21.
//  Copyright © 2021 Sentry. All rights reserved.
//

import Foundation
import Sentry
import UIKit

extension UIViewController {
    func createTransactionObserver(forCallback: @escaping (Span) -> Void) -> SpanObserver? {
        let result = SpanObserver(callback: forCallback)
        if result == nil {
            UIAssert.fail("Transaction was not created")
        }
        return result
    }
}
