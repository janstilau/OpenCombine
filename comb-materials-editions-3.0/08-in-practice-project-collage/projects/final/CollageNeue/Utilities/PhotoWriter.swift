import Foundation
import UIKit
import Photos

import Combine
// 农行 8-9
// 480w 3w 好处费
//
class PhotoWriter {
  enum Error: Swift.Error {
    case couldNotSavePhoto
    case generic(Swift.Error)
  }
  
  /*
   使用, QT 的信号槽来理解, 是不会出现这种单独的异步操作发送信号的情况的.
   因为在 QT 里面, 信号是和对象的声明周期保定在一起的.
   */
  static func saveImgToDisk(_ image: UIImage) -> Future<String, PhotoWriter.Error> {
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
