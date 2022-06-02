import UIKit
import Combine

extension UIViewController {
  // 使用 Combine, 将原有的命令式的代码, 封装成为响应式的一个示例. 
  func alert(title: String, text: String?) -> AnyPublisher<Void, Never> {
    let alertVC = UIAlertController(title: title,
                                    message: text,
                                    preferredStyle: .alert)
    
    return Future { resolve in
      alertVC.addAction(UIAlertAction(title: "Close",
                                      style: .default) { _ in
        resolve(.success(()))
      })
      self.present(alertVC, animated: true, completion: nil)
    }
    .handleEvents(receiveCancel: {
      self.dismiss(animated: true)
    })
    .eraseToAnyPublisher()
  }
}
