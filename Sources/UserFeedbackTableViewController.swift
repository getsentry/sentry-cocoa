//
//  UserFeedbackTableViewController.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 16/11/16.
//
//

import UIKit

public class UserFeedbackTableViewController: UITableViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var messageTextField: UITextField!

    @IBOutlet weak var submitButton: UIButton!
    
    @IBOutlet weak var poweredByTableViewCell: UITableViewCell!
    
    var viewModel = UserFeedbackViewModel() {
        didSet { updateInterface() }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(dismiss))
        tableView.tableFooterView = UIView()
        updateInterface()
    }

    func dismiss() {
        
    }
    
    @IBAction func onClickSubmit(_ sender: AnyObject) {
        SentryClient.shared?.sendUserFeedback()
    }
    
    private func updateInterface() {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subTitle
        
        nameTextField.text = viewModel.nameTextFieldValue
        nameTextField.placeholder = viewModel.nameTextFieldPlaceholder
        
        emailTextField.text = viewModel.emailTextFieldValue
        emailTextField.placeholder = viewModel.emailTextFieldPlaceholder
        
        messageTextField.text = viewModel.messageTextFieldValue
        messageTextField.placeholder = viewModel.messageTextFieldPlaceholder
        
        #if swift(>=3.0)
            submitButton.setTitle(viewModel.submitButtonText, for: .normal)
            poweredByTableViewCell.isHidden = !viewModel.showSentryBranding
        #else
            submitButton.setTitle(viewModel.submitButtonText, forState: .Normal)
            poweredByTableViewCell.hidden = !viewModel.showSentryBranding
        #endif
        
        title = viewModel.viewControllerTitle
    }
    
}
