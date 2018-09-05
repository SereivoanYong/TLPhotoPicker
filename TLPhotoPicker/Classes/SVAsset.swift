//
//  SVAsset.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 18..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import Foundation
import Photos
import PhotosUI
import MobileCoreServices

public struct SVAsset {
  
  enum CloudDownloadState {
    case ready, progress, complete, failed
  }
  
  public enum AssetType {
    case photo, video, livePhoto
  }
  
  public enum ImageExtType: String {
    case png, jpg, gif, heic
  }
  
  var state = CloudDownloadState.ready
  public let phAsset: PHAsset
  public var selectedOrder: Int = 0
  public var type: AssetType {
    switch phAsset.mediaType {
    case .image:
      return phAsset.mediaSubtypes.contains(.photoLive) ? .livePhoto : .photo
    case .video:
      return .video
    default:
      fatalError()
    }
  }
  
  public var fullResolutionImage: UIImage? {
    return SVPhotoLibrary.fullResolutionImageData(asset: phAsset)
  }
  
  public func extType() -> ImageExtType {
    var ext = ImageExtType.png
    if let extention = URL(string: originalFileName)?.pathExtension.lowercased() {
      ext = ImageExtType(rawValue: extention) ?? .png
    }
    return ext
  }
  
  @discardableResult
  public func cloudImageDownload(progressHandler: @escaping (Double) -> Void, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID? {
    return SVPhotoLibrary.cloudImageDownload(asset: phAsset, progressHandler: progressHandler, completion: completion)
  }
  
  public var originalFileName: String {
    return PHAssetResource.assetResources(for: phAsset).first!.originalFilename
  }
  
  public func photoSize(options: PHImageRequestOptions? = nil, completion: @escaping (Int) -> Void, livePhotoVideoSize: Bool = false) {
    guard self.type == .photo else {
      completion(-1)
      return
    }
    var resource: PHAssetResource? = nil
    if phAsset.mediaSubtypes.contains(.photoLive), livePhotoVideoSize {
      resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .pairedVideo }.first
    } else {
      resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .photo }.first
    }
    if let fileSize = resource?.value(forKey: "fileSize") as? Int {
      completion(fileSize)
    } else {
      PHImageManager.default().requestImageData(for: phAsset, options: nil) { data, uti, orientation, info in
        var fileSize = -1
        if let data = data {
          let bcf = ByteCountFormatter()
          bcf.countStyle = .file
          fileSize = data.count
        }
        DispatchQueue.main.async {
          completion(fileSize)
        }
      }
    }
  }
  
  public func videoSize(options: PHVideoRequestOptions? = nil, completion: @escaping (Int) -> Void) {
    guard self.type == .video else {
      completion(-1)
      return
    }
    let resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .video }.first
    if let fileSize = resource?.value(forKey: "fileSize") as? Int {
      completion(fileSize)
    } else {
      PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avasset, audioMix, info in
        func fileSize(_ url: URL?) -> Int? {
          do {
            guard let fileSize = try url?.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
              return nil
            }
            return fileSize
          } catch {
            return nil
          }
        }
        var url: URL? = nil
        if let urlAsset = avasset as? AVURLAsset {
          url = urlAsset.url
        } else if let sandboxKeys = info?["PHImageFileSandboxExtensionTokenKey"] as? String, let path = sandboxKeys.components(separatedBy: ";").last {
          url = URL(fileURLWithPath: path)
        }
        let size = fileSize(url) ?? -1
        DispatchQueue.main.async {
          completion(size)
        }
      }
    }
  }
  
  func MIMEType(_ url: URL?) -> String? {
    guard let ext = url?.pathExtension else {
      return nil
    }
    if !ext.isEmpty {
      let UTIRef = UTTypeCreatePreferredIdentifierForTag("public.filename-extension" as CFString, ext as CFString, nil)
      let UTI = UTIRef?.takeUnretainedValue()
      UTIRef?.release()
      if let UTI = UTI {
        guard let MIMETypeRef = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType) else {
          return nil
        }
        let MIMEType = MIMETypeRef.takeUnretainedValue()
        MIMETypeRef.release()
        return MIMEType as String
      }
    }
    return nil
  }
  
  @discardableResult
  //convertLivePhotosToPNG
  // false : If you want mov file at live photos
  // true  : If you want png file at live photos ( HEIC )
  public func tempCopyMediaFile(videoRequestOptions: PHVideoRequestOptions? = nil, imageRequestOptions: PHImageRequestOptions? = nil, exportPreset: String = AVAssetExportPresetHighestQuality, convertLivePhotosToJPG: Bool = false, progressHandler: ((Double) -> Void)? = nil, completion: @escaping (URL, String) -> Void) -> PHImageRequestID? {
    var type: PHAssetResourceType? = nil
    if phAsset.mediaSubtypes.contains(.photoLive) == true, convertLivePhotosToJPG == false {
      type = .pairedVideo
    } else {
      type = phAsset.mediaType == .video ? .video : .photo
    }
    guard let resource = (PHAssetResource.assetResources(for: phAsset).filter{ $0.type == type }).first else {
      return nil
    }
    var writeURL: URL
    if #available(iOS 10.0, *) {
      writeURL = FileManager.default.temporaryDirectory.appendingPathComponent(resource.originalFilename)
    } else {
      writeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(resource.originalFilename)
    }
    if (writeURL.pathExtension.uppercased() == "HEIC" || writeURL.pathExtension.uppercased() == "HEIF") && convertLivePhotosToJPG {
      let fileName2 = writeURL.deletingPathExtension().lastPathComponent
      writeURL.deleteLastPathComponent()
      writeURL.appendPathComponent(fileName2 + ".jpg")
    }
    guard let mimetype = MIMEType(writeURL) else {
      return nil
    }
    switch phAsset.mediaType {
    case .video:
      var requestOptions = PHVideoRequestOptions()
      if let options = videoRequestOptions {
        requestOptions = options
      } else {
        requestOptions.isNetworkAccessAllowed = true
      }
      // iCloud download progress
      if let progressHandler = progressHandler {
        requestOptions.progressHandler = { progress, error, stop, info in
          DispatchQueue.main.async {
            progressHandler(progress)
          }
        }
      }
      return PHImageManager.default().requestExportSession(forVideo: phAsset, options: requestOptions, exportPreset: exportPreset) { session, infoDict in
        session?.outputURL = writeURL
        session?.outputFileType = AVFileType.mov
        session?.exportAsynchronously {
          DispatchQueue.main.async {
            completion(writeURL, mimetype)
          }
        }
      }
    case .image:
      var requestOptions = PHImageRequestOptions()
      if let options = imageRequestOptions {
        requestOptions = options
      } else {
        requestOptions.isNetworkAccessAllowed = true
      }
      // iCloud download progress
      if let progressHandler = progressHandler {
        requestOptions.progressHandler = { progress, error, stop, info in
          DispatchQueue.main.async {
            progressHandler(progress)
          }
        }
      }
      return PHImageManager.default().requestImageData(for: phAsset, options: requestOptions) { (data, uti, orientation, info) in
        do {
          var data = data
          if convertLivePhotosToJPG, let imgData = data, let rawImage = UIImage(data: imgData)?.upOrientationImage() {
            data = UIImageJPEGRepresentation(rawImage, 1)
          }
          try data?.write(to: writeURL)
          DispatchQueue.main.async {
            completion(writeURL, mimetype)
          }
        } catch {
        }
      }
    default:
      return nil
    }
  }
  
  //Apparently, this method is not be safety to export a video.
  //There is many way that export a video.
  //This method was one of them.
  public func exportVideoFile(options: PHVideoRequestOptions? = nil, progressHandler: ((Float) -> Void)? = nil, completion: @escaping (URL, String) -> Void) {
    guard phAsset.mediaType == .video else {
      return
    }
    var type = PHAssetResourceType.video
    guard let resource = (PHAssetResource.assetResources(for: phAsset).filter{ $0.type == type }).first else {
      return
    }
    let fileName = resource.originalFilename
    let writeURL: URL
    if #available(iOS 10.0, *) {
      writeURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    } else {
      writeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
    }
    guard let mimetype = MIMEType(writeURL) else {
      return
    }
    var requestOptions = PHVideoRequestOptions()
    if let options = options {
      requestOptions = options
    } else {
      requestOptions.isNetworkAccessAllowed = true
    }
    //iCloud download progress
    //options.progressHandler = { (progress, error, stop, info) in
    
    //}
    PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avasset, avaudioMix, infoDict in
      guard let avasset = avasset else {
        return
      }
      let exportSession = AVAssetExportSession(asset: avasset, presetName: AVAssetExportPresetHighestQuality)!
      exportSession.outputURL = writeURL
      exportSession.outputFileType = .mov
      exportSession.exportAsynchronously {
        completion(writeURL, mimetype)
      }
      func checkExportSession() {
        DispatchQueue.global().async { [weak exportSession] in
          guard let exportSession = exportSession else {
            return
          }
          switch exportSession.status {
          case .waiting,.exporting:
            DispatchQueue.main.async {
              progressHandler?(exportSession.progress)
            }
            Thread.sleep(forTimeInterval: 1)
            checkExportSession()
          default:
            break
          }
        }
      }
      checkExportSession()
    }
  }
  
  init(with asset: PHAsset) {
    self.phAsset = asset
  }
}

extension SVAsset: Equatable {
  
  public static func ==(lhs: SVAsset, rhs: SVAsset) -> Bool {
    return lhs.phAsset.localIdentifier == rhs.phAsset.localIdentifier
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
