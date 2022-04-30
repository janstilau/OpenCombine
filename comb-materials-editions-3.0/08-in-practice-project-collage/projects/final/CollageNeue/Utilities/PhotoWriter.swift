import Foundation
import UIKit
import Photos

import Combine

class PhotoWriter {
  enum Error: Swift.Error {
    case couldNotSavePhoto
    case generic(Swift.Error)
  }
  
  static func save(_ image: UIImage) -> Future<String, PhotoWriter.Error> {
    // 使用 Future, 进行了图片存储的过程.
    // 结果, 使用信号发射的方式进行了回调触发.
    Future { resolve in
      do {
        try PHPhotoLibrary.shared().performChangesAndWait {
          let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
          guard let savedAssetID = request.placeholderForCreatedAsset?.localIdentifier else {
            return resolve(.failure(.couldNotSavePhoto))
          }
          
          // 4
          resolve(.success(savedAssetID))
        }
      } catch {
        resolve(.failure(.generic(error)))
      }
    }
  }
}
