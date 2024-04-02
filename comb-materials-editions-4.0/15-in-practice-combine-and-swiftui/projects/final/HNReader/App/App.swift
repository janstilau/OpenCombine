import SwiftUI
import Combine

@main
struct HNReader: App {
    private var subscriptions = Set<AnyCancellable>()
    
    let userSettings = Settings()
    let viewModel = ReaderViewModel()
    
    init() {
        // userSettings.$keywords 的改变, 会直接影响到了 viewModel 里面的数据. 
        userSettings.$keywords
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
