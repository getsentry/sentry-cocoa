//
//  UserFeedbackTableViewController.swift
//  Sentry
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import UIKit

public final class UserFeedbackTableViewController: UITableViewController, UITextFieldDelegate, ViewModelDelegate {
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var nameTextField: UITextField!
    
    @IBOutlet private weak var emailLabel: UILabel!
    @IBOutlet private weak var emailTextField: UITextField!
    
    @IBOutlet private weak var commentsTextField: UITextField!

    @IBOutlet private weak var sentryLogoImageView: UIImageView!
    
    @IBOutlet private weak var emailTableViewCell: UITableViewCell!
    @IBOutlet private weak var nameTableViewCell: UITableViewCell!
    @IBOutlet private weak var poweredByTableViewCell: UITableViewCell!
    
    var viewModel: UserFeedbackViewModel?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        tableView.tableFooterView = UIView()
        viewModel?.delegate = self
        setupInterface()
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
    
    private func setupInterface() {
        guard let viewModel = viewModel else {
            Log.Error.log("UserFeedbackTableViewController has no UserFeedbackViewModel set")
            return
        }
        
        nameTextField.text = viewModel.nameTextFieldValue
        emailTextField.text = viewModel.emailTextFieldValue
        commentsTextField.text = viewModel.commentsTextFieldValue
        nameTextField.textColor = viewModel.defaultTextColor
        emailTextField.textColor = viewModel.defaultTextColor
        commentsTextField.textColor = viewModel.defaultTextColor
        
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subTitle
        
        nameLabel.text = viewModel.nameLabel
        
        emailLabel.text = viewModel.emailLabel

        #if swift(>=3.0)
            commentsTextField.attributedPlaceholder = NSAttributedString(string: viewModel.commentsTextFieldPlaceholder, attributes: [NSForegroundColorAttributeName: UIColor.darkGray])
            poweredByTableViewCell.isHidden = !viewModel.showSentryBranding
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
            if let bundleURL = Bundle(for: type(of: self)).url(forResource: "assets", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL) {
                sentryLogoImageView.image = UIImage(named: "sentry-glyph-black", in: bundle, compatibleWith: nil)
            }
        #else
            commentsTextField.attributedPlaceholder = NSAttributedString(string: viewModel.commentsTextFieldPlaceholder, attributes: [NSForegroundColorAttributeName: UIColor.darkGrayColor()])

            poweredByTableViewCell.hidden = !viewModel.showSentryBranding
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(dismissViewController))
            
            if let bundleURL = NSBundle(forClass: self.dynamicType).URLForResource("assets", withExtension: "bundle"),
                let bundle = NSBundle(URL: bundleURL) {
                sentryLogoImageView.image = UIImage(named: "sentry-glyph-black", inBundle: bundle, compatibleWithTraitCollection: nil)
            }
        #endif
        
        title = viewModel.viewControllerTitle
    }
    
    private func updateInterface() {
        guard let viewModel = viewModel else {
            Log.Error.log("UserFeedbackTableViewController has no UserFeedbackViewModel set")
            return
        }
        
        #if swift(>=3.0)
            let rightBarButton = UIBarButtonItem(title: viewModel.submitButtonText, style: .done, target: self, action: #selector(onClickSubmit))
            navigationItem.rightBarButtonItem = rightBarButton
            rightBarButton.isEnabled = viewModel.submitButtonEnabled
        #else
            let rightBarButton = UIBarButtonItem(title: viewModel.submitButtonText, style: .Done, target: self, action: #selector(onClickSubmit))
            navigationItem.rightBarButtonItem = rightBarButton
            rightBarButton.enabled = viewModel.submitButtonEnabled
        #endif
    }
    
    private func submitUserFeedback() {
        guard let viewModel = viewModel else {
            Log.Error.log("UserFeedbackTableViewController has no UserFeedbackViewModel set")
            return
        }
        
        if let erroredTextField = viewModel.validatedUserFeedback(nameTextField,
                                                                  emailTextField: emailTextField,
                                                                  commentsTextField: commentsTextField) {
            nameTextField.textColor = viewModel.defaultTextColor
            emailTextField.textColor = viewModel.defaultTextColor
            commentsTextField.textColor = viewModel.defaultTextColor
            erroredTextField.becomeFirstResponder()
            erroredTextField.textColor = viewModel.errorTextColor
        } else {
            viewModel.sendUserFeedback { [weak self] _ in
                self?.dismissViewController()
            }
        }
    }
    
    // MARK: ViewModelDelegate
    
    func signalUpdate() {
        updateInterface()
    }
    
    // MARK: UITextFieldDelegate
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        let _ = viewModel?.validatedUserFeedback(nameTextField, emailTextField: emailTextField, commentsTextField: commentsTextField)
    }
    
    #if swift(>=3.0)
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let _ = viewModel?.validatedUserFeedback(nameTextField, emailTextField: emailTextField, commentsTextField: commentsTextField)
        return true
    }
    #else
    public func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        viewModel?.validatedUserFeedback(nameTextField, emailTextField: emailTextField, commentsTextField: commentsTextField)
        return true
    }
    #endif
    
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
