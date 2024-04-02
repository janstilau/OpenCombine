//: [Previous](@previous)
import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()
//:## Mapping errors
example(of: "map vs tryMap") {
    // 1
    enum NameError: Error {
        case tooShort(String)
        case unknown
    }
    
    // 2
    Just("Hello")
        .setFailureType(to: NameError.self) // 3
    // TryMap 就是 Error 产生了之后, 进行 Error 的改变. 
        .tryMap { throw NameError.tooShort($0) }
        .mapError { $0 as? NameError ?? .unknown }
        .sink(
            receiveCompletion: { completion in
                // 5
                switch completion {
                case .finished:
                    print("Done!")
                case .failure(.tooShort(let name)):
                    print("\(name) is too short!")
                case .failure(.unknown):
                    print("An unknown name error occurred")
                }
            },
            receiveValue: { print("Got value \($0)") }
        )
        .store(in: &subscriptions)
}
//: [Next](@next)
