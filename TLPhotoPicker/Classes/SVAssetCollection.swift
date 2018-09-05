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
  var fetchResult: PHFetchResult<PHAsset>
  
  var useCameraButton: Bool = false
  var recentPosition: CGPoint = .zero
  var title: String? {
    return phAssetCollection.localizedTitle
  }
  
  var count: Int {
    return fetchResult.count + (useCameraButton ? 1 : 0)
  }
  
  init(with phAssetCollection: PHAssetCollection, using fetchResult: PHFetchResult<PHAsset>) {
    self.phAssetCollection = phAssetCollection
    self.fetchResult = fetchResult
  }
  
  func getAsset(at index: Int) -> PHAsset? {
    if self.useCameraButton && index == 0 { return nil }
    let index = index - (useCameraButton ? 1 : 0)
    guard index < fetchResult.count else { return nil }
    return fetchResult.object(at: max(index, 0))
  }
  
  func getTLAsset(at index: Int) -> SVAsset? {
    if self.useCameraButton && index == 0 { return nil }
    let index = index - (useCameraButton ? 1 : 0)
    guard index < fetchResult.count else { return nil }
    return SVAsset(with: fetchResult.object(at: max(index, 0)))
  }
  
  func getAssets(at range: CountableClosedRange<Int>) -> [PHAsset]? {
    let lowerBound = range.lowerBound - (self.useCameraButton ? 1 : 0)
    let upperBound = range.upperBound - (self.useCameraButton ? 1 : 0)
    return fetchResult.objects(at: IndexSet(integersIn: max(lowerBound, 0)...min(upperBound,count)))
  }
  
  static func == (lhs: SVAssetCollection, rhs: SVAssetCollection) -> Bool {
    return lhs.phAssetCollection.localIdentifier == rhs.phAssetCollection.localIdentifier
  }
}
