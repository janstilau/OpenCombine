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
        // 这里, 完成了类似于信号槽的机制.
        // 一个信号的发出, 绑定到了另外的一个信号上, 导致另外的一个信号的发出. 
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
