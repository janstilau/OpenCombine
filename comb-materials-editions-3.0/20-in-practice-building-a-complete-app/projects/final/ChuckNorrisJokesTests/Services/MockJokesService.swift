import Foundation
import Combine
@testable import ChuckNorrisJokesModel

struct MockJokesService: JokeServiceDataPublisher {
    let data: Data
    let error: URLError?
    
    init(data: Data, error: URLError? = nil) {
        self.data = data
        self.error = error
    }
    
    func publisher() -> AnyPublisher<Data, URLError> {
        // 1
        let publisher = PassthroughSubject<Data, URLError>()
        
        // 2
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            if let error = error {
                publisher.send(completion: .failure(error))
            } else {
                publisher.send(data)
            }
        }
        
        // 3
        return publisher.eraseToAnyPublisher()
    }
}
