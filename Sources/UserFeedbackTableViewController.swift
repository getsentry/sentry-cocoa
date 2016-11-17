//
//  UserFeedbackTableViewController.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import UIKit

public class UserFeedbackTableViewController: UITableViewController, UITextFieldDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var commentsTextField: UITextField!

    @IBOutlet weak var submitButton: UIButton!
    
    @IBOutlet weak var poweredByTableViewCell: UITableViewCell!
    
    var viewModel: UserFeedbackViewModel?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        #if swift(>=3.0)
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
        #else
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(dismissViewController))
        #endif
        tableView.tableFooterView = UIView()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateInterface()
    }

    func dismissViewController() {
        #if swift(>=3.0)
            dismiss(animated: true, completion: nil)
        #else
            dismissViewControllerAnimated(true, completion: nil)
        #endif
    }
    
    @IBAction func onClickSubmit(_ sender: AnyObject) {
        submitUserFeedback()
    }
    
    private func updateInterface() {
        guard let viewModel = viewModel else {
            SentryLog.Error.log("UserFeedbackTableViewController has no UserFeedbackViewModel set")
            return
        }
        
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subTitle
        
        nameTextField.text = viewModel.nameTextFieldValue
        nameTextField.placeholder = viewModel.nameTextFieldPlaceholder
        
        emailTextField.text = viewModel.emailTextFieldValue
        emailTextField.placeholder = viewModel.emailTextFieldPlaceholder
        
        commentsTextField.text = viewModel.commentsTextFieldValue
        commentsTextField.placeholder = viewModel.commentsTextFieldPlaceholder
        
        #if swift(>=3.0)
            submitButton.setTitle(viewModel.submitButtonText, for: .normal)
            poweredByTableViewCell.isHidden = !viewModel.showSentryBranding
        #else
            submitButton.setTitle(viewModel.submitButtonText, forState: .Normal)
            poweredByTableViewCell.hidden = !viewModel.showSentryBranding
        #endif
        
        title = viewModel.viewControllerTitle
    }
    
    private func submitUserFeedback() {
        guard let viewModel = viewModel else {
            SentryLog.Error.log("UserFeedbackTableViewController has no UserFeedbackViewModel set")
            return
        }
        
        if let erroredTextField = viewModel.validatedUserFeedback(nameTextField: nameTextField,
                                                                  emailTextField: emailTextField,
                                                                  commentsTextField: commentsTextField) {
            erroredTextField.becomeFirstResponder()
        } else {
            viewModel.sendUserFeedback() { [weak self] success in
                self?.dismissViewController()
            }
        }
    }
    
    // MARK: UITextFieldDelegate
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField:
            nameTextField.resignFirstResponder()
            emailTextField.becomeFirstResponder()
        case emailTextField:
            emailTextField.resignFirstResponder()
            commentsTextField.becomeFirstResponder()
        case commentsTextField:
            commentsTextField.resignFirstResponder()
            submitUserFeedback()
        default:
            return true
        }
        return true
    }
}
