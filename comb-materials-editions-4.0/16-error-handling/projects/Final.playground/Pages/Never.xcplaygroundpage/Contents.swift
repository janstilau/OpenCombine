import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()
//: ## Never
example(of: "Never sink") {
    Just("Hello")
        .sink(receiveValue: { print($0) }) // Just 也可以调用完整的版本, 这个值接受值的, 其实是特殊的形式包装.
        .store(in: &subscriptions)
}

enum MyError: Error {
    case ohNo
}

example(of: "setFailureType") {
    Just("Hello")
        .setFailureType(to: MyError.self)
        .sink(
            receiveCompletion: { completion in
                switch completion {
                    // 2
                case .failure(.ohNo):
                    print("Finished with Oh No!")
                case .finished:
                    print("Finished successfully!")
                }
            },
            receiveValue: { value in
                print("Got value: \(value)")
            }
        )
        .store(in: &subscriptions)
}

example(of: "assign(to:on:)") {
    // 1
    class Person {
        let id = UUID()
        var name = "Unknown"
    }
    
    // 2
    let person = Person()
    print("1", person.name)
    
    Just("Shai")
        .handleEvents( // 3
            receiveCompletion: { _ in print("2", person.name) }
        )
        .assign(to: \.name, on: person) // 4
        .store(in: &subscriptions)
}

//example(of: "assign(to:)") {
//  class MyViewModel: ObservableObject {
//    @Published var currentDate = Date()
//
//    init() {
//      Timer.publish(every: 1, on: .main, in: .common)
//        .autoconnect() // 1
//        .prefix(3) // 2
//        .assign(to: &$currentDate)
//    }
//  }
//
//  // 4
//  let vm = MyViewModel()
//  vm.$currentDate
//    .sink(receiveValue: { print($0) })
//    .store(in: &subscriptions)
//}

example(of: "assertNoFailure") {
    // 1
    Just("Hello")
        .setFailureType(to: MyError.self)
    //    .tryMap { _ in throw MyError.ohNo }
        .assertNoFailure() // 2, 这其实就是把 Error 变味了 Never.
        .sink(receiveValue: { print("Got value: \($0) ")}) // 3
        .store(in: &subscriptions)
}
//: [Next](@next)
