//
//  ImageList.swift
//  iOS-Swift
//
//  Created by Andrew McKnight on 6/29/23.
//  Copyright © 2023 Sentry. All rights reserved.
//

import Foundation

class ImageListCell: UITableViewCell {
    func configureWithImage(image: UIImage, efficient: Bool) {
        guard efficient else {
            imageView?.image = image
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if #available(iOS 15.0, *) {
                let preparedImage = image.preparingForDisplay()
                DispatchQueue.main.async {
                    self.imageView?.image = preparedImage
                }
            }
        }
    }
}

class ImageList: UITableViewController {
    let efficient: Bool
    init(efficient: Bool) {
        self.efficient = efficient
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ImageListCell.self, forCellReuseIdentifier: "Cell")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let name = "\((arc4random() % 64) + 1)"
        let url = Bundle.main.url(forResource: name, withExtension: "PNG")!
        let data = try! Data(contentsOf: url)
        let image = UIImage(data: data)!
        if let imageCell = cell as? ImageListCell {
            imageCell.configureWithImage(image: image, efficient: efficient)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 65 * 100
    }
}
