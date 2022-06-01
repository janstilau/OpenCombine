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
    
    // 一个计算属性, allStories 存储了所有的数据, filter 存储了过滤的数据.
    // 每当, 上面的 @Published 的值改变, UI 层都会调用 Stories 重新生成自己需要展示的数据. 计算属性就是方法.
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
    
    // ViewAction 触发的 ModelAction. 来进行实际的数据层面的改变.
    // 这里就是通过网络, 进行数据的修改, 然后引起信号的改变. 
    func fetchStories() {
        api
            .stories()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.error = error
                }
            }, receiveValue: { stories in
                // 虽然, 这是一个 Private, 但是不妨碍他能触发 objectWillChanged 信号的触发. 
                self.allStories = stories
                self.error = nil
            })
            .store(in: &subscriptions)
    }
}
