import SwiftUI

// 使用的 Swfit UI 来构建的整个 App 的视图. 
@main
struct CollageNeueApp: App {
  var body: some Scene {
    WindowGroup {
      MainView().environmentObject(CollageNeueModel())
    }
  }
}
