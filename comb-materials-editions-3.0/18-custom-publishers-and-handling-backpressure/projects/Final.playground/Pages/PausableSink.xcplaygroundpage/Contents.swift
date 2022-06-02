import Combine
import Foundation

protocol Pausable {
    var paused: Bool { get }
    func resume()
}

// 1
// 自定义一个 Subscriber. 在里面, 会有 Demand 的管理.
final class PausableSubscriber<Input, Failure: Error>:
    Subscriber, Pausable, Cancellable {
    // 2
    let combineIdentifier = CombineIdentifier()
    
    // 3
    let receiveValue: (Input) -> Bool
    // 4
    let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
    
    // 5
    private var subscription: Subscription? = nil
    // 6
    var paused = false
    
    // 7
    init(receiveValue: @escaping (Input) -> Bool,
         receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void) {
        self.receiveValue = receiveValue
        self.receiveCompletion = receiveCompletion
    }
    
    // 8
    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
    
    func receive(subscription: Subscription) {
        // 9
        self.subscription = subscription
        // 10
        subscription.request(.max(1))
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        // 11
        paused = receiveValue(input) == false
        // 12
        return paused ? .none : .max(1)
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        // 13
        receiveCompletion(completion)
        subscription = nil
    }
    
    func resume() {
        guard paused else { return }
        
        paused = false
        // 14
        subscription?.request(.max(1))
    }
}

extension Publisher {
    // 15
    func pausableSink(
        receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void),
        receiveValue: @escaping ((Output) -> Bool))
    -> Pausable & Cancellable {
        // 16
        let pausable = PausableSubscriber(
            receiveValue: receiveValue,
            receiveCompletion: receiveCompletion)
        self.subscribe(pausable)
        // 17
        return pausable
    }
}

let subscription = [1, 2, 3, 4, 5, 6]
    .publisher
    .pausableSink(receiveCompletion: { completion in
        print("Pausable subscription completed: \(completion)")
    }) { value -> Bool in
        print("Receive value: \(value)")
        if value % 2 == 1 {
            print("Pausing")
            return false
        }
        return true
    }

let timer = Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink { _ in
        guard subscription.paused else { return }
        print("Subscription is paused, resuming")
        subscription.resume()
    }
