import Combine
import UIKit
import Photos

class CollageNeueModel: ObservableObject {
  static let collageSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
  
  // MARK: - Collage
  
  private(set) var lastSavedPhotoID = ""
  private(set) var lastErrorMessage = ""
  private var subscriptions = Set<AnyCancellable>()
  private let currentImages = CurrentValueSubject<[UIImage], Never>([])
  @Published var imagePreview: UIImage?
  let updateUISubject = PassthroughSubject<Int, Never>()
  
  private(set) var selectedPhotosSubject =
  PassthroughSubject<UIImage, Never>()
  
  func bindMainView() {
    // 1
    currentImages
      .handleEvents(receiveOutput: { [weak self] photos in
        self?.updateUISubject.send(photos.count)
      })
    // 2
      .map { photos in
        UIImage.collage(images: photos, size: Self.collageSize)
      }
      .assign(to: &$imagePreview)
  }
  
  func add() {
    selectedPhotosSubject = PassthroughSubject<UIImage, Never>()
    let newPhotos = selectedPhotosSubject
      .eraseToAnyPublisher()
      .prefix(while: { [unowned self] _ in
        self.currentImages.value.count < 6
      })
      .share()
    
    newPhotos
      .map { [unowned self] newImage in
        // 1
        return self.currentImages.value + [newImage]
      }
    // 2
      .assign(to: \.value, on: currentImages)
    // 3
      .store(in: &subscriptions)
  }
  
  func clear() {
    currentImages.send([])
  }
  
  func save() {
    guard let image = imagePreview else { return }
    
    // 1
    PhotoWriter.save(image)
      .sink(
        receiveCompletion: { [unowned self] completion in
          // 2
          if case .failure(let error) = completion {
            lastErrorMessage = error.localizedDescription
          }
          clear()
        },
        receiveValue: { [unowned self] id in
          // 3
          lastSavedPhotoID = id
        }
      )
      .store(in: &subscriptions)
  }
  
  // MARK: -  Displaying photos picker
  private lazy var imageManager = PHCachingImageManager()
  private(set) var thumbnails = [String: UIImage]()
  private let thumbnailSize = CGSize(width: 200, height: 200)
  
  func bindPhotoPicker() {
    
  }
  
  func loadPhotos() -> PHFetchResult<PHAsset> {
    let allPhotosOptions = PHFetchOptions()
    allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    return PHAsset.fetchAssets(with: allPhotosOptions)
  }
  
  func enqueueThumbnail(asset: PHAsset) {
    guard thumbnails[asset.localIdentifier] == nil else { return }
    
    imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
      guard let image = image else { return }
      self.thumbnails[asset.localIdentifier] = image
    })
  }
  
  func selectImage(asset: PHAsset) {
    imageManager.requestImage(
      for: asset,
      targetSize: UIScreen.main.bounds.size,
      contentMode: .aspectFill,
      options: nil
    ) { [weak self] image, info in
      guard let self = self,
            let image = image,
            let info = info else { return }
      
      if let isThumbnail = info[PHImageResultIsDegradedKey as String] as? Bool, isThumbnail {
        // Skip the thumbnail version of the asset
        return
      }
      
      self.selectedPhotosSubject.send(image)
    }
  }
}
