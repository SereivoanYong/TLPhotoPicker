//
//  TLPhotosPickerViewController.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 14..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import MobileCoreServices

public protocol TLPhotosPickerViewControllerDelegate: AnyObject {
  
  func dismissPhotoPicker(withPHAssets: [SVAsset])
  func dismissComplete()
  func photoPickerDidCancel()
  func canSelectAsset(phAsset: PHAsset) -> Bool
  func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController)
  func handleNoAlbumPermissions(picker: TLPhotosPickerViewController)
  func handleNoCameraPermissions(picker: TLPhotosPickerViewController)
}

extension TLPhotosPickerViewControllerDelegate {
  
  public func deninedAuthoization() { }
  public func dismissPhotoPicker(withPHAssets: [PHAsset]) { }
  public func dismissComplete() { }
  public func photoPickerDidCancel() { }
  public func canSelectAsset(phAsset: PHAsset) -> Bool { return true }
  public func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController) { }
  public func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) { }
  public func handleNoCameraPermissions(picker: TLPhotosPickerViewController) { }
}

public struct SVPhotosPickerConfiguration {
  
  public var defaultCameraRollTitle = "Camera Roll"
  public var tapHereToChange = "Tap here to change"
  public var cancelTitle = "Cancel"
  public var doneTitle = "Done"
  public var emptyMessage = "No albums"
  public var emptyImage: UIImage? = nil
  public var usedCameraButton = true
  public var usedPrefetch = false
  public var allowedLivePhotos = true
  public var allowedVideo = true
  public var allowedAlbumCloudShared = false
  public var allowedVideoRecording = true
  public var recordingVideoQuality: UIImagePickerControllerQualityType = .typeMedium
  public var maxVideoDuration: TimeInterval?
  public var autoPlay = true
  public var muteAudio = true
  public var mediaType: PHAssetMediaType?
  public var numberOfColumn = 3
  public var singleSelectedMode = false
  public var maxSelectedAssets: Int? = nil
  public var fetchOption: PHFetchOptions?
  public var selectedColor = UIColor(red: 88/255, green: 144/255, blue: 255/255, alpha: 1)
  public var cameraBgColor = UIColor(red: 221/255, green: 223/255, blue: 226/255, alpha: 1)
  public var cameraIcon = TLBundle.podBundleImage(named: "camera")
  public var videoIcon = TLBundle.podBundleImage(named: "video")
  public var placeholderIcon = TLBundle.podBundleImage(named: "insertPhotoMaterial")
  public var nibSet: (nibName: String, bundle:Bundle)?
  public var cameraCellNibSet: (nibName: String, bundle:Bundle)?
  
  public init() {
    
  }
}

public struct Platform {
  
  public static var isSimulator: Bool {
    return TARGET_OS_SIMULATOR != 0 // Use this line in Xcode 7 or newer
  }
}

open class TLPhotosPickerViewController: UIViewController {
  
  lazy open var cancelBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
  lazy open var doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))
  
  @IBOutlet open var titleView: UIView!
  @IBOutlet open var titleLabel: UILabel!
  @IBOutlet open var subTitleStackView: UIStackView!
  @IBOutlet open var subTitleLabel: UILabel!
  @IBOutlet open var subTitleArrowImageView: UIImageView!
  @IBOutlet var albumPopView: TLAlbumPopView!
  @IBOutlet open var collectionView: UICollectionView!
  @IBOutlet open var indicator: UIActivityIndicatorView!
  @IBOutlet open var popArrowImageView: UIImageView!
  @IBOutlet open var emptyView: UIView!
  @IBOutlet open var emptyImageView: UIImageView!
  @IBOutlet open var emptyMessageLabel: UILabel!
  
  weak open var delegate: TLPhotosPickerViewControllerDelegate?
  open var selectedAssets: [SVAsset] = []
  public var configuration: SVPhotosPickerConfiguration = SVPhotosPickerConfiguration()
  
  @objc open var canSelectAsset: ((PHAsset) -> Bool)?
  @objc open var didExceedMaximumNumberOfSelection: ((TLPhotosPickerViewController) -> Void)?
  @objc open var handleNoAlbumPermissions: ((TLPhotosPickerViewController) -> Void)?
  @objc open var handleNoCameraPermissions: ((TLPhotosPickerViewController) -> Void)?
  @objc open var dismissCompletion: (() -> Void)?
  fileprivate var completionWithTLPHAssets: (([SVAsset]) -> Void)?
  fileprivate var didCancel: (() -> Void)?
  
  fileprivate var collections = [SVAssetCollection]()
  fileprivate var focusedCollection: SVAssetCollection?
  fileprivate var requestIds: [IndexPath: PHImageRequestID] = [:]
  fileprivate var playRequestId: (indexPath: IndexPath, requestId: PHImageRequestID)?
  fileprivate var photoLibrary = SVPhotoLibrary()
  fileprivate var queue = DispatchQueue(label: "tilltue.photos.pikcker.queue")
  fileprivate var thumbnailSize = CGSize.zero
  fileprivate var placeholderThumbnail: UIImage?
  fileprivate var cameraImage: UIImage?
  
  deinit {
    //print("deinit TLPhotosPickerViewController")
    PHPhotoLibrary.shared().unregisterChangeObserver(self)
  }
  
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public init() {
    super.init(nibName: "TLPhotosPickerViewController", bundle: Bundle(for: TLPhotosPickerViewController.self))
  }
  
  convenience public init(withTLPHAssets: (([SVAsset]) -> Void)? = nil, didCancel: (() -> Void)? = nil) {
    self.init()
    self.completionWithTLPHAssets = withTLPHAssets
    self.didCancel = didCancel
  }
  
  open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }
  
  open override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    self.stopPlay()
  }
  
  func checkAuthorization() {
    switch PHPhotoLibrary.authorizationStatus() {
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { [weak self] status in
        switch status {
        case .authorized:
          self?.initPhotoLibrary()
        default:
          self?.handleDeniedAlbumsAuthorization()
        }
      }
    case .authorized:
      self.initPhotoLibrary()
    case .restricted, .denied:
      handleDeniedAlbumsAuthorization()
    }
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    
    makeUI()
    checkAuthorization()
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if self.thumbnailSize == CGSize.zero {
      initItemSize()
    }
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    if self.photoLibrary.delegate == nil {
      initPhotoLibrary()
    }
  }
}

// MARK: - UI & UI Action
extension TLPhotosPickerViewController {
  
  @objc public func registerNib(nibName: String, bundle: Bundle) {
    self.collectionView.register(UINib(nibName: nibName, bundle: bundle), forCellWithReuseIdentifier: nibName)
  }
  
  fileprivate func centerAtRect(image: UIImage?, rect: CGRect, bgColor: UIColor = UIColor.white) -> UIImage? {
    guard let image = image else { return nil }
    UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
    bgColor.setFill()
    UIRectFill(CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
    image.draw(in: CGRect(x:rect.size.width/2 - image.size.width/2, y:rect.size.height/2 - image.size.height/2, width:image.size.width, height:image.size.height))
    let result = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return result
  }
  
  fileprivate func initItemSize() {
    guard let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
    let count = CGFloat(configuration.numberOfColumn)
    let width = (self.view.frame.size.width-(5*(count-1)))/count
    self.thumbnailSize = CGSize(width: width, height: width)
    layout.itemSize = self.thumbnailSize
    self.collectionView.collectionViewLayout = layout
    self.placeholderThumbnail = centerAtRect(image: configuration.placeholderIcon, rect: CGRect(x: 0, y: 0, width: width, height: width))
    self.cameraImage = centerAtRect(image: configuration.cameraIcon, rect: CGRect(x: 0, y: 0, width: width, height: width), bgColor: self.configuration.cameraBgColor)
  }
  
  @objc open func makeUI() {
    registerNib(nibName: "TLPhotoCollectionViewCell", bundle: Bundle(for: TLPhotoCollectionViewCell.self))
    if let nibSet = configuration.nibSet {
      registerNib(nibName: nibSet.nibName, bundle: nibSet.bundle)
    }
    if let nibSet = configuration.cameraCellNibSet {
      registerNib(nibName: nibSet.nibName, bundle: nibSet.bundle)
    }
    self.indicator.startAnimating()
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleTap))
    self.titleView.addGestureRecognizer(tapGesture)
    self.titleLabel.text = configuration.defaultCameraRollTitle
    self.subTitleLabel.text = configuration.tapHereToChange
    self.cancelBarButtonItem.title = configuration.cancelTitle
    self.doneBarButtonItem.title = configuration.doneTitle
    self.doneBarButtonItem.setTitleTextAttributes([.font: UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)], for: .normal)
    self.emptyView.isHidden = true
    self.emptyImageView.image = configuration.emptyImage
    self.emptyMessageLabel.text = configuration.emptyMessage
    self.albumPopView.tableView.delegate = self
    self.albumPopView.tableView.dataSource = self
    popArrowImageView.image = TLBundle.podBundleImage(named: "pop_arrow")
    subTitleArrowImageView.image = TLBundle.podBundleImage(named: "arrow")
    if #available(iOS 10.0, *), configuration.usedPrefetch {
      collectionView.isPrefetchingEnabled = true
      collectionView.prefetchDataSource = self
    } else {
      configuration.usedPrefetch = false
    }
    if #available(iOS 9.0, *), configuration.allowedLivePhotos {
    } else {
      configuration.allowedLivePhotos = false
    }
    
    navigationItem.titleView = titleView
    navigationItem.leftBarButtonItem = cancelBarButtonItem
    navigationItem.rightBarButtonItem = doneBarButtonItem
  }
  
  fileprivate func updateTitle() {
    guard self.focusedCollection != nil else { return }
    self.titleLabel.text = self.focusedCollection?.title
  }
  
  fileprivate func reloadCollectionView() {
    guard self.focusedCollection != nil else { return }
    self.collectionView.reloadData()
  }
  
  fileprivate func reloadTableView() {
    let count = min(5, self.collections.count)
    var frame = self.albumPopView.popupView.frame
    frame.size.height = CGFloat(count * 75)
    self.albumPopView.popupViewHeight.constant = CGFloat(count * 75)
    UIView.animate(withDuration: self.albumPopView.show ? 0.1:0) {
      self.albumPopView.popupView.frame = frame
      self.albumPopView.setNeedsLayout()
    }
    self.albumPopView.tableView.reloadData()
    self.albumPopView.setupPopupFrame()
  }
  
  fileprivate func initPhotoLibrary() {
    if PHPhotoLibrary.authorizationStatus() == .authorized {
      photoLibrary.delegate = self
      photoLibrary.fetchCollection(configure: configuration)
    } else {
      //self.dismiss(animated: true, completion: nil)
    }
  }
  
  fileprivate func registerChangeObserver() {
    PHPhotoLibrary.shared().register(self)
  }
  
  fileprivate func getfocusedIndex() -> Int {
    guard let focused = self.focusedCollection, let result = self.collections.index(where: { $0 == focused }) else { return 0 }
    return result
  }
  
  fileprivate func cancelAllImageAssets() {
    for (_,requestId) in self.requestIds {
      self.photoLibrary.cancelPHImageRequest(requestId: requestId)
    }
    self.requestIds.removeAll()
  }
  
  // User Action
  @objc func titleTap() {
    guard collections.count > 0 else { return }
    self.albumPopView.show(self.albumPopView.isHidden)
  }
  
  @objc open func cancel(_ sender: Any) {
    self.stopPlay()
    self.dismiss(done: false)
  }
  
  @objc open func done(_ sender: Any) {
    self.stopPlay()
    self.dismiss(done: true)
  }
  
  fileprivate func dismiss(done: Bool) {
    if done {
      self.delegate?.dismissPhotoPicker(withPHAssets: self.selectedAssets.compactMap{ $0.phAsset })
      self.completionWithTLPHAssets?(self.selectedAssets)
    } else {
      self.delegate?.photoPickerDidCancel()
      self.didCancel?()
    }
    self.dismiss(animated: true) { [weak self] in
      self?.delegate?.dismissComplete()
      self?.dismissCompletion?()
    }
  }
  
  fileprivate func canSelect(phAsset: PHAsset) -> Bool {
    if let closure = self.canSelectAsset {
      return closure(phAsset)
    }else if let delegate = self.delegate {
      return delegate.canSelectAsset(phAsset: phAsset)
    }
    return true
  }
  
  fileprivate func maxCheck() -> Bool {
    if self.configuration.singleSelectedMode {
      self.selectedAssets.removeAll()
      self.orderUpdateCells()
    }
    if let max = self.configuration.maxSelectedAssets, max <= self.selectedAssets.count {
      self.delegate?.didExceedMaximumNumberOfSelection(picker: self)
      self.didExceedMaximumNumberOfSelection?(self)
      return true
    }
    return false
  }
}

// MARK: - TLPhotoLibraryDelegate
extension TLPhotosPickerViewController: TLPhotoLibraryDelegate {
  func loadCameraRollCollection(collection: SVAssetCollection) {
    if let focused = self.focusedCollection, focused == collection {
      focusCollection(collection: collection)
    }
    self.collections = [collection]
    self.indicator.stopAnimating()
    self.reloadCollectionView()
    self.reloadTableView()
  }
  
  func loadCompleteAllCollection(collections: [SVAssetCollection]) {
    self.collections = collections
    let isEmpty = self.collections.count == 0
    self.subTitleStackView.isHidden = isEmpty
    self.emptyView.isHidden = !isEmpty
    self.emptyImageView.isHidden = self.emptyImageView.image == nil
    self.indicator.stopAnimating()
    self.reloadTableView()
    self.registerChangeObserver()
  }
  
  func focusCollection(collection: SVAssetCollection) {
    self.focusedCollection = collection
    self.updateTitle()
  }
}

// MARK: - Camera Picker
extension TLPhotosPickerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  fileprivate func showCameraIfAuthorized() {
    let cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    switch cameraAuthorization {
    case .authorized:
      self.showCamera()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] (authorized) in
        DispatchQueue.main.async { [weak self] in
          if authorized {
            self?.showCamera()
          } else {
            self?.handleDeniedCameraAuthorization()
          }
        }
      })
    case .restricted, .denied:
      self.handleDeniedCameraAuthorization()
    }
  }
  
  fileprivate func showCamera() {
    guard !maxCheck() else {
      return
    }
    let pickerController = UIImagePickerController()
    pickerController.sourceType = .camera
    pickerController.mediaTypes = [kUTTypeImage as String]
    if configuration.allowedVideoRecording {
      pickerController.mediaTypes.append(kUTTypeMovie as String)
      pickerController.videoQuality = configuration.recordingVideoQuality
      if let duration = configuration.maxVideoDuration {
        pickerController.videoMaximumDuration = duration
      }
    }
    pickerController.allowsEditing = false
    pickerController.delegate = self
    present(pickerController, animated: true, completion: nil)
  }
  
  fileprivate func handleDeniedAlbumsAuthorization() {
    delegate?.handleNoAlbumPermissions(picker: self)
    handleNoAlbumPermissions?(self)
  }
  
  fileprivate func handleDeniedCameraAuthorization() {
    delegate?.handleNoCameraPermissions(picker: self)
    handleNoCameraPermissions?(self)
  }
  
  open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
  
  open func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
      var placeholderAsset: PHObjectPlaceholder?
      PHPhotoLibrary.shared().performChanges({
        placeholderAsset = PHAssetChangeRequest.creationRequestForAsset(from: image).placeholderForCreatedAsset
      }, completionHandler: { [weak self] success, error in
        if success, let `self` = self, let identifier = placeholderAsset?.localIdentifier {
          guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
          var result = SVAsset(with: asset)
          result.selectedOrder = self.selectedAssets.count + 1
          self.selectedAssets.append(result)
        }
      })
    }
    else if (info[UIImagePickerControllerMediaType] as? String) == kUTTypeMovie as String {
      var placeholderAsset: PHObjectPlaceholder? = nil
      PHPhotoLibrary.shared().performChanges({
        let newAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: info[UIImagePickerControllerMediaURL] as! URL)!
        placeholderAsset = newAssetRequest.placeholderForCreatedAsset
      }, completionHandler: { [weak self] success, error in
        if success, let `self` = self, let identifier = placeholderAsset?.localIdentifier {
          guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            return
          }
          var result = SVAsset(with: asset)
          result.selectedOrder = self.selectedAssets.count + 1
          self.selectedAssets.append(result)
        }
      })
    }
    picker.dismiss(animated: true, completion: nil)
  }
}

// MARK: - UICollectionView Scroll Delegate

extension TLPhotosPickerViewController {
  
  open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      videoCheck()
    }
  }
  
  open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    videoCheck()
  }
  
  fileprivate func videoCheck() {
    func play(asset: (IndexPath,SVAsset)) {
      if self.playRequestId?.indexPath != asset.0 {
        playVideo(asset: asset.1, indexPath: asset.0)
      }
    }
    guard configuration.autoPlay, playRequestId == nil else {
      return
    }
    let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
    let boundAssets = visibleIndexPaths.compactMap{ indexPath -> (IndexPath,SVAsset)? in
      guard let asset = self.focusedCollection?.getTLAsset(at: indexPath.row), asset.phAsset.mediaType == .video else { return nil }
      return (indexPath,asset)
    }
    if let firstSelectedVideoAsset = (boundAssets.filter{ getSelectedAssets($0.1) != nil }.first) {
      play(asset: firstSelectedVideoAsset)
    } else if let firstVideoAsset = boundAssets.first {
      play(asset: firstVideoAsset)
    }
    
  }
}
// MARK: - Video & LivePhotos Control PHLivePhotoViewDelegate
extension TLPhotosPickerViewController : PHLivePhotoViewDelegate {
  
  fileprivate func stopPlay() {
    guard let playRequest = self.playRequestId else { return }
    self.playRequestId = nil
    guard let cell = self.collectionView.cellForItem(at: playRequest.indexPath) as? TLPhotoCollectionViewCell else { return }
    cell.stopPlay()
  }
  
  fileprivate func playVideo(asset: SVAsset, indexPath: IndexPath) {
    stopPlay()
    if asset.type == .video {
      guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
      let requestId = self.photoLibrary.videoAsset(asset: asset.phAsset, completion: { (playerItem, info) in
        DispatchQueue.main.sync { [weak self, weak cell] in
          guard let `self` = self, let cell = cell, cell.player == nil else { return }
          let player = AVPlayer(playerItem: playerItem)
          cell.player = player
          player.play()
          player.isMuted = self.configuration.muteAudio
        }
      })
      if requestId > 0 {
        self.playRequestId = (indexPath,requestId)
      }
    } else if asset.type == .livePhoto {
      
      guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
      let requestId = self.photoLibrary.livePhotoAsset(asset: asset.phAsset, size: self.thumbnailSize, completion: { [weak cell] (livePhoto,complete) in
        cell?.livePhotoView?.isHidden = false
        cell?.livePhotoView?.livePhoto = livePhoto
        cell?.livePhotoView?.isMuted = true
        cell?.livePhotoView?.startPlayback(with: .hint)
      })
      if requestId > 0 {
        self.playRequestId = (indexPath,requestId)
      }
    }
  }
  
  public func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    livePhotoView.isMuted = true
    livePhotoView.startPlayback(with: .hint)
  }
  
  public func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
  }
}

// MARK: - PHPhotoLibraryChangeObserver
extension TLPhotosPickerViewController: PHPhotoLibraryChangeObserver {
  
  public func photoLibraryDidChange(_ changeInstance: PHChange) {
    guard getfocusedIndex() == 0 else { return }
    guard let changeFetchResult = self.focusedCollection?.fetchResult else { return }
    guard let changes = changeInstance.changeDetails(for: changeFetchResult) else { return }
    let addIndex = configuration.usedCameraButton ? 1 : 0
    DispatchQueue.main.sync {
      if changes.hasIncrementalChanges {
        var deletedSelectedAssets = false
        var order = 0
        self.selectedAssets = self.selectedAssets.enumerated().compactMap({ (offset,asset) -> SVAsset? in
          var asset = asset
          if changes.fetchResultAfterChanges.contains(asset.phAsset) {
            order += 1
            asset.selectedOrder = order
            return asset
          }
          deletedSelectedAssets = true
          return nil
        })
        if deletedSelectedAssets {
          self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
          self.collectionView.reloadData()
        } else {
          self.collectionView.performBatchUpdates({ [weak self] in
            guard let `self` = self else { return }
            self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
            if let removed = changes.removedIndexes, removed.count > 0 {
              self.collectionView.deleteItems(at: removed.map { IndexPath(item: $0+addIndex, section:0) })
            }
            if let inserted = changes.insertedIndexes, inserted.count > 0 {
              self.collectionView.insertItems(at: inserted.map { IndexPath(item: $0+addIndex, section:0) })
            }
            if let changed = changes.changedIndexes, changed.count > 0 {
              self.collectionView.reloadItems(at: changed.map { IndexPath(item: $0+addIndex, section:0) })
            }
          }, completion: nil)
        }
      } else {
        self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
        self.collectionView.reloadData()
      }
      if let collection = self.focusedCollection {
        self.collections[getfocusedIndex()] = collection
        self.albumPopView.tableView.reloadRows(at: [IndexPath(row: getfocusedIndex(), section: 0)], with: .none)
      }
    }
  }
}

// MARK: - UICollectionView delegate & datasource
extension TLPhotosPickerViewController : UICollectionViewDataSource, UICollectionViewDataSourcePrefetching, UICollectionViewDelegate {
  
  fileprivate func getSelectedAssets(_ asset: SVAsset) -> SVAsset? {
    if let index = self.selectedAssets.index(where: { $0.phAsset == asset.phAsset }) {
      return self.selectedAssets[index]
    }
    return nil
  }
  
  fileprivate func orderUpdateCells() {
    let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
    for indexPath in visibleIndexPaths {
      guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { continue }
      guard let asset = self.focusedCollection?.getTLAsset(at: indexPath.row) else { continue }
      if let selectedAsset = getSelectedAssets(asset) {
        cell.selectedAsset = true
        cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
      } else {
        cell.selectedAsset = false
      }
    }
  }
  
  //Delegate
  open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let collection = self.focusedCollection, let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
    if collection.useCameraButton && indexPath.row == 0 {
      if Platform.isSimulator {
        print("not supported by the simulator.")
        return
      } else {
        if configuration.cameraCellNibSet?.nibName != nil {
          cell.selectedCell()
        } else {
          showCameraIfAuthorized()
        }
        return
      }
    }
    guard var asset = collection.getTLAsset(at: indexPath.row) else { return }
    cell.popScaleAnim()
    if let index = self.selectedAssets.index(where: { $0.phAsset == asset.phAsset }) {
      //deselect
      self.selectedAssets.remove(at: index)
      self.selectedAssets = self.selectedAssets.enumerated().compactMap({ (offset,asset) -> SVAsset? in
        var asset = asset
        asset.selectedOrder = offset + 1
        return asset
      })
      cell.selectedAsset = false
      cell.stopPlay()
      self.orderUpdateCells()
      if self.playRequestId?.indexPath == indexPath {
        stopPlay()
      }
    } else {
      //select
      guard !maxCheck() else { return }
      guard canSelect(phAsset: asset.phAsset) else { return }
      asset.selectedOrder = self.selectedAssets.count + 1
      self.selectedAssets.append(asset)
      cell.selectedAsset = true
      cell.orderLabel?.text = "\(asset.selectedOrder)"
      if asset.type != .photo, configuration.autoPlay {
        playVideo(asset: asset, indexPath: indexPath)
      }
    }
  }
  
  open func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if let cell = cell as? TLPhotoCollectionViewCell {
      cell.endDisplayingCell()
      cell.stopPlay()
      if indexPath == self.playRequestId?.indexPath {
        self.playRequestId = nil
      }
    }
    guard let requestId = self.requestIds[indexPath] else { return }
    self.requestIds.removeValue(forKey: indexPath)
    self.photoLibrary.cancelPHImageRequest(requestId: requestId)
  }
  
  //Datasource
  open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    func makeCell(nibName: String) -> TLPhotoCollectionViewCell {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: nibName, for: indexPath) as! TLPhotoCollectionViewCell
      cell.configure = configuration
      cell.imageView?.image = self.placeholderThumbnail
      cell.liveBadgeImageView = nil
      return cell
    }
    let nibName = configuration.nibSet?.nibName ?? "TLPhotoCollectionViewCell"
    var cell = makeCell(nibName: nibName)
    guard let collection = self.focusedCollection else { return cell }
    cell.isCameraCell = collection.useCameraButton && indexPath.row == 0
    if cell.isCameraCell {
      if let nibName = configuration.cameraCellNibSet?.nibName {
        cell = makeCell(nibName: nibName)
      }else{
        cell.imageView?.image = self.cameraImage
      }
      cell.willDisplayCell()
      return cell
    }
    guard let asset = collection.getTLAsset(at: indexPath.row) else {
      return cell
    }
    if let selectedAsset = getSelectedAssets(asset) {
      cell.selectedAsset = true
      cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
    } else {
      cell.selectedAsset = false
    }
    if asset.state == .progress {
      cell.indicator?.startAnimating()
    }else {
      cell.indicator?.stopAnimating()
    }
    if configuration.usedPrefetch {
      let options = PHImageRequestOptions()
      options.deliveryMode = .opportunistic
      options.resizeMode = .exact
      options.isNetworkAccessAllowed = true
      let requestId = self.photoLibrary.imageAsset(asset: asset.phAsset, size: self.thumbnailSize, options: options) { [weak self, weak cell] image, complete in
        guard let `self` = self else { return }
        DispatchQueue.main.async {
          if self.requestIds[indexPath] != nil {
            cell?.imageView?.image = image
            cell?.update(with: asset.phAsset)
            if self.configuration.allowedVideo {
              cell?.durationView?.isHidden = asset.type != .video
              cell?.duration = asset.type == .video ? asset.phAsset.duration : nil
            }
            if complete {
              self.requestIds.removeValue(forKey: indexPath)
            }
          }
        }
      }
      if requestId > 0 {
        self.requestIds[indexPath] = requestId
      }
    } else {
      queue.async { [weak self, weak cell] in
        guard let `self` = self else { return }
        let requestId = self.photoLibrary.imageAsset(asset: asset.phAsset, size: self.thumbnailSize, completion: { (image,complete) in
          DispatchQueue.main.async {
            if self.requestIds[indexPath] != nil {
              cell?.imageView?.image = image
              cell?.update(with: asset.phAsset)
              if self.configuration.allowedVideo {
                cell?.durationView?.isHidden = asset.type != .video
                cell?.duration = asset.type == .video ? asset.phAsset.duration : nil
              }
              if complete {
                self.requestIds.removeValue(forKey: indexPath)
              }
            }
          }
        })
        if requestId > 0 {
          self.requestIds[indexPath] = requestId
        }
      }
    }
    if configuration.allowedLivePhotos {
      cell.liveBadgeImageView?.image = asset.type == .livePhoto ? PHLivePhotoView.livePhotoBadgeImage(options: .overContent) : nil
      cell.livePhotoView?.delegate = asset.type == .livePhoto ? self : nil
    }
    cell.alpha = 0
    UIView.transition(with: cell, duration: 0.1, options: .curveEaseIn, animations: {
      cell.alpha = 1
    }, completion: nil)
    return cell
  }
  
  open func numberOfSections(in collectionView: UICollectionView) -> Int {
    if let focusCollection = focusedCollection {
      return 1
    }
    return 0
  }
  
  open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return focusedCollection!.count
  }
  
  //Prefetch
  open func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    if configuration.usedPrefetch {
      queue.async { [weak self] in
        guard let `self` = self, let collection = self.focusedCollection else { return }
        var assets = [PHAsset]()
        for indexPath in indexPaths {
          if let asset = collection.getAsset(at: indexPath.row) {
            assets.append(asset)
          }
        }
        let scale = max(UIScreen.main.scale,2)
        let targetSize = CGSize(width: self.thumbnailSize.width*scale, height: self.thumbnailSize.height*scale)
        self.photoLibrary.imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
      }
    }
  }
  
  open func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    if configuration.usedPrefetch {
      for indexPath in indexPaths {
        guard let requestId = self.requestIds[indexPath] else { continue }
        self.photoLibrary.cancelPHImageRequest(requestId: requestId)
        self.requestIds.removeValue(forKey: indexPath)
      }
      queue.async { [weak self] in
        guard let `self` = self, let collection = self.focusedCollection else { return }
        var assets = [PHAsset]()
        for indexPath in indexPaths {
          if let asset = collection.getAsset(at: indexPath.row) {
            assets.append(asset)
          }
        }
        let scale = max(UIScreen.main.scale,2)
        let targetSize = CGSize(width: self.thumbnailSize.width*scale, height: self.thumbnailSize.height*scale)
        self.photoLibrary.imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
      }
    }
  }
  
  open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    if configuration.usedPrefetch, let cell = cell as? TLPhotoCollectionViewCell, let collection = self.focusedCollection, let asset = collection.getTLAsset(at: indexPath.row) {
      if let selectedAsset = getSelectedAssets(asset) {
        cell.selectedAsset = true
        cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
      } else {
        cell.selectedAsset = false
      }
    }
  }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension TLPhotosPickerViewController : UITableViewDataSource, UITableViewDelegate {
  
  open func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.collections.count
  }
  
  open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return tableView.dequeueReusableCell(withIdentifier: "TLCollectionTableViewCell", for: indexPath)
  }
  
  open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    let cell = cell as! SVCollectionTableViewCell
    let collection = self.collections[indexPath.row]
    cell.titleLabel.text = collection.title
    cell.subtitleLabel.text = "\(collection.fetchResult.count)"
    if let phAsset = collection.getAsset(at: collection.useCameraButton ? 1 : 0) {
      let scale = UIScreen.main.scale
      let size = CGSize(width: 80*scale, height: 80*scale)
      self.photoLibrary.imageAsset(asset: phAsset, size: size, completion: { [weak cell] (image,complete) in
        DispatchQueue.main.async {
          cell?.thumbnailImageView.image = image
        }
      })
    }
    cell.accessoryType = getfocusedIndex() == indexPath.row ? .checkmark : .none
    cell.selectionStyle = .none
  }
  
  open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let collection = collections[indexPath.row]
    func resetRequest() {
      cancelAllImageAssets()
    }
    resetRequest()
    self.collections[getfocusedIndex()].recentPosition = self.collectionView.contentOffset
    var reloadIndexPaths = [IndexPath(row: getfocusedIndex(), section: 0)]
    self.focusedCollection = collection
    self.focusedCollection?.fetchResult = self.photoLibrary.fetchResult(collection: collection, configure: self.configuration)
    reloadIndexPaths.append(IndexPath(row: getfocusedIndex(), section: 0))
    self.albumPopView.tableView.reloadRows(at: reloadIndexPaths, with: .none)
    self.albumPopView.show(false, duration: 0.2)
    self.updateTitle()
    self.reloadCollectionView()
    self.collectionView.contentOffset = collection.recentPosition
  }
}
