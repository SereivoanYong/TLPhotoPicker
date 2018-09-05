//
//  TLAlbumPopView.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 19..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import UIKit

class TLAlbumPopView: UIView {
  
  @IBOutlet var bgView: UIView!
  @IBOutlet var popupView: UIView!
  @IBOutlet var popupViewHeight: NSLayoutConstraint!
  @IBOutlet var tableView: UITableView!
  var originalFrame = CGRect.zero
  var show = false
  
  deinit {
    //        print("deinit TLAlbumPopView")
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    popupView.layer.cornerRadius = 5.0
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapBgView))
    bgView.addGestureRecognizer(tapGesture)
    tableView.register(SVCollectionTableViewCell.self, forCellReuseIdentifier: "TLCollectionTableViewCell")
  }
  
  @objc func tapBgView() {
    show(false)
  }
  
  fileprivate func getFrame(scale: CGFloat) -> CGRect {
    var frame = originalFrame
    frame.size.width = frame.size.width * scale
    frame.size.height = frame.size.height * scale
    frame.origin.x = self.frame.width/2 - frame.width/2
    return frame
  }
  
  func setupPopupFrame() {
    if originalFrame != popupView.frame {
      originalFrame = popupView.frame
    }
  }
  
  func show(_ show: Bool, duration: TimeInterval = 0.1) {
    guard self.show != show else {
      return
    }
    layer.removeAllAnimations()
    isHidden = false
    popupView.frame = show ? getFrame(scale: 0.1) : popupView.frame
    bgView.alpha = show ? 0 : 1
    UIView.animate(withDuration: duration, animations: {
      self.bgView.alpha = show ? 1 : 0
      self.popupView.transform = show ? CGAffineTransform(scaleX: 1.05, y: 1.05) : CGAffineTransform(scaleX: 0.1, y: 0.1)
      self.popupView.frame = show ? self.getFrame(scale: 1.05) : self.getFrame(scale: 0.1)
    }, completion: { _ in
      self.isHidden = !show
      UIView.animate(withDuration: duration) {
        if show {
          self.popupView.transform = CGAffineTransform(scaleX: 1, y: 1)
          self.popupView.frame = self.originalFrame
        }
        self.show = show
      }
    })
  }
}
