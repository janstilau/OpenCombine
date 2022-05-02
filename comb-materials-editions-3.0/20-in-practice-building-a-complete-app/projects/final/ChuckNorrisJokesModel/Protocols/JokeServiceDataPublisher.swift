import Foundation
import Combine

public protocol JokeServiceDataPublisher {
    func publisher() -> AnyPublisher<Data, URLError>
}
