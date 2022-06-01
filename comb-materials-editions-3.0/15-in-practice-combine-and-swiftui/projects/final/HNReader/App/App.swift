import SwiftUI
import Combine

@main
struct HNReader: App {
    private var subscriptions = Set<AnyCancellable>()
    
    let userSettings = Settings()
    let viewModel = ReaderViewModel()
    
    init() {
        // $keywords 的修改, 导致了 主ViewModel 中的数据变化. 是
        userSettings.$keywords
        // 非常烂的代码, 怎么就不能写清楚了呢.
            .map { $0.map { $0.value } }
            .assign(to: \.filter, on: viewModel)
            .store(in: &subscriptions)
    }
    
    var body: some Scene {
        WindowGroup {
            ReaderView(model: viewModel)
                .environmentObject(userSettings)
                .onAppear {
                    viewModel.fetchStories()
                }
        }
    }
}
