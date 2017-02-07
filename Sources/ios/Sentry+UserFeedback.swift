//
//  Sentry+UserFeedback.swift
//  Sentry
//
//  Created by Daniel Griesser on 07/02/2017.
//
//

import Foundation
#if os(iOS)
import UIKit
#endif

#if os(iOS)
@objc public protocol SentryClientUserFeedbackDelegate {
    func userFeedbackReady()
    func userFeedbackSent()
}
#endif

extension SentryClient {
    public typealias UserFeedbackViewContollers = (navigationController: UINavigationController, userFeedbackTableViewController: UserFeedbackTableViewController)
    
    #if os(iOS)
    @objc public func userFeedbackTableViewController() -> UserFeedbackTableViewController? {
        return userFeedbackControllers()?.userFeedbackTableViewController
    }
    
    @objc public func userFeedbackNavigationViewController() -> UINavigationController? {
        return userFeedbackControllers()?.navigationController
    }
    
    /// Call this with your custom UserFeedbackViewModel to configure the UserFeedbackViewController
    @objc public func enableUserFeedbackAfterFatalEvent(userFeedbackViewModel: UserFeedbackViewModel = UserFeedbackViewModel()) {
        self.userFeedbackViewModel = userFeedbackViewModel
    }
    
    /// This will return the UserFeedbackControllers
    public func userFeedbackControllers() -> UserFeedbackViewContollers? {
        guard userFeedbackViewControllers == nil else {
            return userFeedbackViewControllers
        }
        
        var bundle: Bundle? = nil
        #if swift(>=3.0)
            let frameworkBundle = Bundle(for: type(of: self))
            bundle = frameworkBundle
            if let bundleURL = frameworkBundle.url(forResource: "storyboards", withExtension: "bundle") {
                bundle = Bundle(url: bundleURL)
            }
        #else
            let frameworkBundle = NSBundle(forClass: self.dynamicType)
            bundle = frameworkBundle
            if let bundleURL = frameworkBundle.URLForResource("storyboards", withExtension: "bundle") {
            bundle = NSBundle(URL: bundleURL)
            }
        #endif
        
        let storyboard = UIStoryboard(name: "UserFeedback", bundle: bundle)
        if let navigationViewController = storyboard.instantiateInitialViewController() as? UINavigationController,
            let userFeedbackViewController = navigationViewController.viewControllers.first as? UserFeedbackTableViewController,
            let viewModel = userFeedbackViewModel {
            userFeedbackViewController.viewModel = viewModel
            userFeedbackViewControllers = (navigationViewController, userFeedbackViewController)
            return userFeedbackViewControllers
        }
        return nil
    }
    
    internal func sentUserFeedback() {
        #if swift(>=3.0)
            DispatchQueue.main.async {
                self.delegate?.userFeedbackSent()
            }
        #else
            dispatch_async(dispatch_get_main_queue(), {
            self.delegate?.userFeedbackSent()
            })
        #endif
        lastSuccessfullySentEvent = nil
    }
    #endif
}
