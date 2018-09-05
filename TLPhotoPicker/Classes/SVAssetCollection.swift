//
//  TLAssetsCollection.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 18..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import Foundation
import Photos

struct SVAssetCollection {
  
  let phAssetCollection: PHAssetCollection
  var fetchResult: PHFetchResult<PHAsset>? = nil
  var useCameraButton: Bool = false
  var recentPosition: CGPoint = CGPoint.zero
  var title: String
  
  var count: Int {
    get {
      guard let count = self.fetchResult?.count, count > 0 else { return self.useCameraButton ? 1 : 0 }
      return count + (self.useCameraButton ? 1 : 0)
    }
  }
  
  init(with phAssetCollection: PHAssetCollection) {
    self.phAssetCollection = phAssetCollection
    self.title = phAssetCollection.localizedTitle ?? ""
  }
  
  func getAsset(at index: Int) -> PHAsset? {
    if self.useCameraButton && index == 0 { return nil }
    let index = index - (self.useCameraButton ? 1 : 0)
    guard let result = self.fetchResult, index < result.count else { return nil }
    return result.object(at: max(index,0))
  }
  
  func getTLAsset(at index: Int) -> SVAsset? {
    if self.useCameraButton && index == 0 { return nil }
    let index = index - (self.useCameraButton ? 1 : 0)
    guard let result = self.fetchResult, index < result.count else { return nil }
    return SVAsset(with: result.object(at: max(index,0)))
  }
  
  func getAssets(at range: CountableClosedRange<Int>) -> [PHAsset]? {
    let lowerBound = range.lowerBound - (self.useCameraButton ? 1 : 0)
    let upperBound = range.upperBound - (self.useCameraButton ? 1 : 0)
    return self.fetchResult?.objects(at: IndexSet(integersIn: max(lowerBound,0)...min(upperBound,count)))
  }
  
  static func ==(lhs: SVAssetCollection, rhs: SVAssetCollection) -> Bool {
    return lhs.phAssetCollection.localIdentifier == rhs.phAssetCollection.localIdentifier
  }
}

extension UIImage {
  func upOrientationImage() -> UIImage? {
    switch imageOrientation {
    case .up:
      return self
    default:
      UIGraphicsBeginImageContextWithOptions(size, false, scale)
      draw(in: CGRect(origin: .zero, size: size))
      let result = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      return result
    }
  }
}
