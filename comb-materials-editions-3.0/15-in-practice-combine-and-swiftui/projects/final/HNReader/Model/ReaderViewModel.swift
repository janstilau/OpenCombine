import Combine
import Foundation

class ReaderViewModel: ObservableObject {
    
    private let api = API()
    private var subscriptions = Set<AnyCancellable>()
    
    // 可以是, @Published + Private 的这种组合, 仅仅是为了通知外界, 发生了变化. 
    @Published private var allStories = [Story]()
    @Published var error: API.Error? = nil
    @Published var filter = [String]()
    // filter 的改变, 会引起 View 的刷新, 而在 View 中, 真正使用的, 是 stories 的值.
    
    var stories: [Story] {
        guard !filter.isEmpty else {
            return allStories
        }
        return allStories
            .filter { story -> Bool in
                return filter.reduce(false) { isMatch, keyword -> Bool in
                    return isMatch || story.title.lowercased().contains(keyword)
                }
            }
    }
    
    
    func fetchStories() {
        api
            .stories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.error = error
                }
            }, receiveValue: { stories in
                self.allStories = stories
                self.error = nil
            })
            .store(in: &subscriptions)
    }
}
