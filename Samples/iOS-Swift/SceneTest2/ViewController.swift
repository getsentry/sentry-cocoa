//
//  ViewController.swift
//  SceneTest2
//
//  Created by Noah Martin on 8/27/25.
//

import UIKit

class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    let v = UIView()
    v.backgroundColor = .red
    let label = UILabel()
    label.textColor = UIColor.black
    label.text = "Repro: window appears only after foreground"
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false
    v.addSubview(label)
    NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: v.centerYAnchor)
    ])
    self.view = v
  }


}

