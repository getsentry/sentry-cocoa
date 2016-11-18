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

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    
    @IBOutlet weak var commentsTextField: UITextField!

    @IBOutlet weak var sentryLogoImageView: UIImageView!
    
    @IBOutlet weak var emailTableViewCell: UITableViewCell!
    @IBOutlet weak var nameTableViewCell: UITableViewCell!
    @IBOutlet weak var poweredByTableViewCell: UITableViewCell!
    
    var viewModel: UserFeedbackViewModel?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
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
    
    func onClickSubmit() {
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
        nameLabel.text = viewModel.nameLabel
        
        emailTextField.text = viewModel.emailTextFieldValue
        emailLabel.text = viewModel.emailLabel
        
        commentsTextField.text = viewModel.commentsTextFieldValue
        commentsTextField.placeholder = viewModel.commentsTextFieldPlaceholder
        
        #if swift(>=3.0)
            poweredByTableViewCell.isHidden = !viewModel.showSentryBranding
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: viewModel.submitButtonText, style: .done, target: self, action: #selector(onClickSubmit))
            
            if let bundleURL = Bundle(for: type(of: self)).url(forResource: "assets", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL) {
            sentryLogoImageView.image = UIImage(named: "sentry-glyph-black", in: bundle, compatibleWith: nil)
            }
        #else
            poweredByTableViewCell.hidden = !viewModel.showSentryBranding
           
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(dismissViewController))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: viewModel.submitButtonText, style: .Done, target: self, action: #selector(onClickSubmit))
            
            if let bundleURL = NSBundle(forClass: self.dynamicType).URLForResource("assets", withExtension: "bundle"),
                let bundle = NSBundle(URL: bundleURL) {
                sentryLogoImageView.image = UIImage(named: "sentry-glyph-black", inBundle: bundle, compatibleWithTraitCollection: nil)
            }
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
            nameTextField.textColor = viewModel.defaultTextColor
            emailTextField.textColor = viewModel.defaultTextColor
            commentsTextField.textColor = viewModel.defaultTextColor
            erroredTextField.becomeFirstResponder()
            erroredTextField.textColor = viewModel.errorTextColor
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
    
    // MARK: UITableViewControllerDelegate
    #if swift(>=3.0)
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        switch cell {
        case nameTableViewCell:
            nameTextField.becomeFirstResponder()
        case emailTableViewCell:
            emailTextField.becomeFirstResponder()
        default:
            break
        }
    }
    #else
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let cell = tableView.cellForRowAtIndexPath(indexPath) else {
            return
        }
        
        switch cell {
        case nameTableViewCell:
            nameTextField.becomeFirstResponder()
        case emailTableViewCell:
            emailTextField.becomeFirstResponder()
        default:
            break
        }
    }
    #endif
    
}
