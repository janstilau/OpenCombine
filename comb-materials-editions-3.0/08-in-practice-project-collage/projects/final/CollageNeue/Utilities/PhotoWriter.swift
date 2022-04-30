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
    Future { resolve in
      do {
        try PHPhotoLibrary.shared().performChangesAndWait {
          // 1
          let request = PHAssetChangeRequest.creationRequestForAsset(from: image)

          // 2
          guard let savedAssetID =
            request.placeholderForCreatedAsset?.localIdentifier else {
            // 3
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
