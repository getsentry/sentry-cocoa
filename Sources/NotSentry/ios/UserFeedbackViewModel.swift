//
//  UserFeedbackViewModel.swift
//  Sentry
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import UIKit

protocol ViewModelDelegate: class {
    func signalUpdate()
}

protocol ViewModel {
    weak var delegate: ViewModelDelegate? { get }
}

@objc(SentryUserFeedbackViewModel)public final class UserFeedbackViewModel: NSObject, ViewModel {
    
    public var viewControllerTitle = "User Feedback"
    
    public var title = "It looks like we're having some internal issues."
    public var subTitle = "Our team has been notified. If you'd like to help, tell us what happened below."
    
    public var nameLabel = "Name:"
    public var nameTextFieldValue = SentryClient.shared?.user?.username
    
    public var emailLabel = "Email:"
    public var emailTextFieldValue = SentryClient.shared?.user?.email
    
    public var commentsTextFieldPlaceholder = "I clicked X and then this happened ..."
    public var commentsTextFieldValue = ""
    
    public var submitButtonText = "Submit"
    
    #if swift(>=3.0)
        public var errorTextColor = #colorLiteral(red:0.93, green:0.26, blue:0.22, alpha:1.0)
    #else
        public var errorTextColor = UIColor(red:0.93, green:0.26, blue:0.22, alpha:1.0)
    #endif
    
    #if swift(>=3.0)
        public var defaultTextColor = UIColor.darkText
    #else
        public var defaultTextColor = UIColor.darkTextColor()
    #endif
    
    public var showSentryBranding = true
    
    private(set) var name: String?
    private(set) var email: String?
    private(set) var comments: String?
    
    var submitButtonEnabled: Bool {
        return name != nil && email != nil && comments != nil
    }

    weak var delegate: ViewModelDelegate?
    
    func sendUserFeedback(finished: SentryEndpointRequestFinished? = nil) {
        guard let name = self.name, let email = self.email, let comments = self.comments else {
            Log.Error.log("UserFeedback must be filled")
            return
        }
        
        let userFeedback = UserFeedback()
        userFeedback.name = name
        userFeedback.email = email
        userFeedback.comments = comments
        
        SentryClient.shared?.sendUserFeedback(userFeedback, finished: finished)
    }
    
    func validatedUserFeedback(_ nameTextField: UITextField, emailTextField: UITextField, commentsTextField: UITextField) -> UITextField? {
        defer {
            delegate?.signalUpdate()
        }
        
        #if swift(>=3.0)
            guard let name = nameTextField.text, "" != name else {
                self.name = nil
                return nameTextField
            }
            guard let email = emailTextField.text, "" != email, validateEmail(email) else {
                self.email = nil
                return emailTextField
            }
            guard let comments = commentsTextField.text, "" != comments else {
                self.comments = nil
                return commentsTextField
            }
        #else
            guard let name = nameTextField.text where "" != name else {
                self.name = nil
                return nameTextField
            }
            guard let email = emailTextField.text where "" != email && validateEmail(email) else {
                self.email = nil
                return emailTextField
            }
            guard let comments = commentsTextField.text where "" != comments else {
                self.comments = nil
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
