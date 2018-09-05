//
//  PhotoPickerWithNavigationViewController.swift
//  TLPhotoPicker
//
//  Created by wade.hawk on 2017. 7. 24..
//  Copyright © 2017년 CocoaPods. All rights reserved.
//

import Foundation
import TLPhotoPicker

class PhotoPickerWithNavigationViewController: TLPhotosPickerViewController {
    override func makeUI() {
        super.makeUI()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .cancel, target: self, action: #selector(customAction))
    }
    @objc func customAction() {
        self.dismiss(animated: true, completion: nil)
    }
  
    override func done(_ sender: Any) {
        let imagePreviewVC = ImagePreviewViewController()
        imagePreviewVC.assets = self.selectedAssets.first
        self.navigationController?.pushViewController(imagePreviewVC, animated: true)
    }
}
