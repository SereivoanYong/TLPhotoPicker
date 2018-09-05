//
//  CustomPhotoPickerViewController.swift
//  TLPhotoPicker
//
//  Created by wade.hawk on 2017. 5. 28..
//  Copyright © 2017년 CocoaPods. All rights reserved.
//

import Foundation
import TLPhotoPicker

class CustomPhotoPickerViewController: TLPhotosPickerViewController {
    override func makeUI() {
        super.makeUI()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .cancel, target: self, action: #selector(customAction))
    }
    @objc func customAction() {
        self.dismiss(animated: true, completion: nil)
    }
}
