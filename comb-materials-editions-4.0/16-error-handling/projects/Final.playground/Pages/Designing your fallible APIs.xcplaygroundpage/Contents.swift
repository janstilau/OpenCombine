//: [Previous](@previous)
import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()
//: ## Designing your fallible APIs
example(of: "Joke API") {
    class DadJokes {
        // 1
        struct Joke: Codable {
            let id: String
            let joke: String
        }
        
        enum Error: Swift.Error, CustomStringConvertible {
            // 1
            case network
            case jokeDoesntExist(id: String)
            case parsing
            case unknown
            
            // 2
            var description: String {
                switch self {
                case .network:
                    return "Request to API Server failed"
                case .parsing:
                    return "Failed parsing response from server"
                case .jokeDoesntExist(let id):
                    return "Joke with ID \(id) doesn't exist"
                case .unknown:
                    return "An unknown error occurred"
                }
            }
        }
        
        // 2
        //
        func getJoke(id: String) -> AnyPublisher<Joke, Error> {
            // 如果数据不对, 直接可以发送一个失败的数据过来.
            guard id.rangeOfCharacter(from: .letters) != nil else {
                return Fail<Joke, Error>(
                    error: .jokeDoesntExist(id: id)
                )
                .eraseToAnyPublisher()
            }
            
            let url = URL(string: "https://icanhazdadjoke.com/j/\(id)")!
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = ["Accept": "application/json"]
            
            // 3
            return URLSession.shared
                .dataTaskPublisher(for: request)
                .tryMap { data, _ -> Data in
                    // 6 这里是解析的过程.
                    guard let obj = try? JSONSerialization.jsonObject(with: data),
                          let dict = obj as? [String: Any],
                          dict["status"] as? Int == 404 else {
                        return data
                    }
                    
                    // 7
                    throw DadJokes.Error.jokeDoesntExist(id: id)
                }
                .decode(type: Joke.self, decoder: JSONDecoder())
                .mapError { error -> DadJokes.Error in
                    // 将 Error 进行类型的变化.
                    switch error {
                    case is URLError:
                        return .network
                    case is DecodingError:
                        return .parsing
                    default:
                        return error as? DadJokes.Error ?? .unknown
                    }
                }
                .eraseToAnyPublisher()
        }
    }
    
    // 4
    let api = DadJokes()
    let jokeID = "9prWnjyImyd"
    let badJokeID = "123456"
    
    // 5
    api
        .getJoke(id: jokeID)
        .sink(receiveCompletion: { print($0) },
              receiveValue: { print("Got joke: \($0)") })
        .store(in: &subscriptions)
}
//: [Next](@next)
