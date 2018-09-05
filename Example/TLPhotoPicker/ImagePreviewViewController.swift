//
//  ImagePreviewViewController.swift
//  TLPhotoPicker
//
//  Created by wade.hawk on 2017. 7. 24..
//  Copyright © 2017년 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import TLPhotoPicker

class ImagePreviewViewController: UIViewController {
    @IBOutlet var imageView: UIImageView!
    
    var assets: SVAsset? = nil
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(nibName: "ImagePreviewViewController", bundle: Bundle.main)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = self.assets?.fullResolutionImage
    }
}
