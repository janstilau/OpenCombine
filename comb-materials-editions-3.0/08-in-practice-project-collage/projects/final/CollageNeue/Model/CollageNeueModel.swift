
import Combine
import UIKit
import Photos

// ViewModel 就是 Controller 类.
class CollageNeueModel: ObservableObject {
  static let collageSize = CGSize(width: UIScreen.main.bounds.width, height: 200)
  
  // 注意权限控制.
  private(set) var lastSavedPhotoID = ""
  private(set) var lastErrorMessage = ""
  // DisposeBag 对象.
  private var subscriptions = Set<AnyCancellable>()
  // CurrentValueSubject 是一个引用对象, 所以是 Let.
  // CurrentValueSubject 的每次变化, 引起 imagePreview 的变化, imagePreview 是真正和 UI 监护的数据源.
  private let images = CurrentValueSubject<[UIImage], Never>([])
  @Published var imagePreview: UIImage?
  
  // PassthroughSubject 是一个引用对象. 是代表着当前选中图片的数量.
  let updateUISubject = PassthroughSubject<Int, Never>()
  
  private(set) var selectedPhotosSubject = PassthroughSubject<UIImage, Never>()
  
  func bindMainView() {
    // 1
    /*
     images 的信号变化, 引起了 updateUISubject 的数字变化. -> UI 的变化.
     images 的信号变化, 生成了新的合成图. 然后新的合成图赋值到 imagePreview 上 -> UI 的变化.
     */
    images
      .handleEvents(receiveOutput: { [weak self] photos in
        // 触发了 updateUISubject 的信号变化.
        self?.updateUISubject.send(photos.count)
      })
    // 2
      .map { photos in
        // 生成了新的图像.
        UIImage.collage(images: photos, size: Self.collageSize)
      }
    // 这样会有循环引用.
//      .assign(to: .imagePreview, on: self)
    // 触发了 $imagePreview 的信号变化.
    // 这样, 没有循环引用.
      .assign(to: &$imagePreview)
  }
  
  func add() {
    // 不太明白, 这个值为什么要每次都新创建.
    // 因为, 每次都在 PhotoView 消失的时候, PassthroughSubject 都发送了 Compelteion 事件.
    selectedPhotosSubject = PassthroughSubject<UIImage, Never>()
    // selectedPhotosSubject 的变化, 会触发后面的事件变化.
    
    // 新的信号.
    let newPhotos = selectedPhotosSubject
      .eraseToAnyPublisher()
      .prefix(while: { [unowned self] _ in
        self.images.value.count < 6
      })
      .share()
    
    // 每次新选中的图片.
    newPhotos
    // 和之前的图片, 加在一起, 转化成为了图片数组.
      .map { [unowned self] newImage in
        // 1
        return self.images.value + [newImage]
      }
    // 2
    // 图片数组, 触发了 images 的变化.
    // images 的变化的触发, 在 bindMainView 中进行了绑定.
      .assign(to: \.value, on: images)
    // 3
      .store(in: &subscriptions)
    
    // 如果, 不把结果放在 subscriptions 里面, 那么
  }
  
  func clear() {
    images.send([])
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
  
  // 通过 ViewModel. 进行真正的业务数据的提取工作. 这本身也是 ViewController 的职责.
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
    
    imageManager.requestImage(for: asset,
                                 targetSize: UIScreen.main.bounds.size,
                                 contentMode: .aspectFill,
                                 options: nil) { [weak self] image, info in
      guard let self = self,
            let image = image,
            let info = info else { return }
      
      //      if let isThumbnail = info[PHImageResultIsDegradedKey as String] as? Bool, isThumbnail {
      //        // Skip the thumbnail version of the asset
      //        return
      //      }
      //
      self.selectedPhotosSubject.send(image)
    }
  }
}
