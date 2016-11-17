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
    
    var commentsTextFieldPlaceholder = "I clicked X and then this happened ..."
    var commentsTextFieldValue = ""
    
    var submitButtonText = "Submit crash report"
    
    var errorTextColor = UIColor(red:0.93, green:0.26, blue:0.22, alpha:1.0)
    
    #if swift(>=3.0)
        var defaultTextColor = UIColor.darkText
    #else
        var defaultTextColor = UIColor.darkGrayColor()
    #endif
    
    var showSentryBranding = true
    
    private(set) var name: String?
    private(set) var email: String?
    private(set) var comments: String?
    
    func sendUserFeedback(finished: SentryEndpointRequestFinished? = nil) {
        guard let name = self.name, let email = self.email, let comments = self.comments else {
            SentryLog.Error.log("UserFeedback must be filled")
            return
        }
        
        let userFeedback = UserFeedback()
        userFeedback.name = name
        userFeedback.email = email
        userFeedback.comments = comments
        
        SentryClient.shared?.sendUserFeedback(userFeedback, finished: finished)
    }
    
    func validatedUserFeedback(nameTextField nameTextField: UITextField, emailTextField: UITextField, commentsTextField: UITextField) -> UITextField? {
        #if swift(>=3.0)
            guard let name = nameTextField.text, "" != name else {
                return nameTextField
            }
            guard let email = emailTextField.text, "" != email, validateEmail(email) else {
                return emailTextField
            }
            guard let comments = commentsTextField.text, "" != comments else {
                return commentsTextField
            }
        #else
            guard let name = nameTextField.text where "" != name else {
                return nameTextField
            }
            guard let email = emailTextField.text where "" != email && validateEmail(email) else {
                return emailTextField
            }
            guard let comments = commentsTextField.text where "" != comments else {
                return commentsTextField
            }
        #endif
        
        self.name = name
        self.email = email
        self.comments = comments
        
        return nil
    }
    
    private func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
        #if swift(>=3.0)
            return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
        #else
            return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluateWithObject(email)
        #endif
    }
}
