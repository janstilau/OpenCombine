import Foundation
import PlaygroundSupport
import Combine

struct API {
    /// API Errors.
    // 使用 Enum 来进行 Error 的处理.
    enum Error: LocalizedError {
        case addressUnreachable(URL)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "The server responded with garbage."
            case .addressUnreachable(let url): return "\(url.absoluteString) is unreachable."
            }
        }
    }
    
    /// API endpoints.
    enum EndPoint {
        static let baseURL = URL(string: "https://hacker-news.firebaseio.com/v0/")!
        
        case stories
        case story(Int)
        
        var url: URL {
            switch self {
            case .stories:
                return EndPoint.baseURL.appendingPathComponent("newstories.json")
            case .story(let id):
                return EndPoint.baseURL.appendingPathComponent("item/\(id).json")
            }
        }
    }
    
    /// Maximum number of stories to fetch (reduce for lower API strain during development).
    var maxStories = 10
    
    /// A shared JSON decoder to use in calls.
    private let decoder = JSONDecoder()
    
    private let apiQueue = DispatchQueue(label: "API",
                                         qos: .default,
                                         attributes: .concurrent)
    
    // 这里讲的是, 如何将原来的回调方法, 变为了返回 AnyPublisher 的方式.
    func story(id: Int) -> AnyPublisher<Story, Error> {
        URLSession.shared
            .dataTaskPublisher(for: EndPoint.story(id).url)
            .receive(on: apiQueue) // 进行后方处理环境的切换.
            .map(\.data) // 数据的提取.
            .decode(type: Story.self, decoder: decoder) // decode 的处理.
            .catch { _ in Empty<Story, Error>() }
            .eraseToAnyPublisher()
    }
    
    func mergedStories(ids storyIDs: [Int]) -> AnyPublisher<Story, Error> {
        let storyIDs = Array(storyIDs.prefix(maxStories))
        precondition(!storyIDs.isEmpty)
        
        let initialPublisher = story(id: storyIDs[0])
        let remainder = Array(storyIDs.dropFirst())
        
        return remainder.reduce(initialPublisher) { combined, id in
            // merge 是将原有的 Publisher 合并到一个 Publisher 的 Operator, 也就是所有的数据, 都到了一个平面了.
            return combined
                .merge(with: story(id: id))
                .eraseToAnyPublisher()
        }
    }
    
    func stories() -> AnyPublisher<[Story], Error> {
        URLSession.shared
            .dataTaskPublisher(for: EndPoint.stories.url)
            .map(\.data)
            .decode(type: [Int].self, decoder: decoder)
        // 将 URL 的 Error, 变为 API.Error 的形式.
            .mapError { error -> API.Error in
                switch error {
                case is URLError:
                    return Error.addressUnreachable(EndPoint.stories.url)
                default:
                    return Error.invalidResponse
                }
            }
            .filter { !$0.isEmpty }
            .flatMap { storyIDs in
                // 将一个值, 变为另外的一个 Publisher 的方式.
                return self.mergedStories(ids: storyIDs)
            }
            .scan([]) { stories, story -> [Story] in
                return stories + [story]
            }
            .map { $0.sorted() }
            .eraseToAnyPublisher()
    }
}

let api = API()
var subscriptions = [AnyCancellable]()

api.stories()
    .sink(receiveCompletion: { print($0) },
          receiveValue: { print($0) })
    .store(in: &subscriptions)
