//
//  UserFeedbackViewModel.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import UIKit

public class UserFeedbackViewModel {
    
    var viewControllerTitle = "User Feedback"
    
    var title = "It looks like we're having some internal issues."
    var subTitle = "Our team has been notified. If you'd like to help, tell us what happened below."
    
    var nameTextFieldPlaceholder = "Name"
    var nameTextFieldValue = ""
    
    var emailTextFieldPlaceholder = "Email"
    var emailTextFieldValue = ""
    
    var messageTextFieldPlaceholder = "I clicked X and then this happened ..."
    var messageTextFieldValue = ""
    
    var submitButtonText = "Submit crash report"
    
    var showSentryBranding = true
    
}
