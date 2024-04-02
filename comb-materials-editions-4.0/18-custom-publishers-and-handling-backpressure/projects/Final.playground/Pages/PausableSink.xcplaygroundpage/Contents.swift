import Combine
import Foundation

// 这是一个经常看到的例子 .

protocol Pausable {
    var paused: Bool { get }
    func resume()
}

/*
 最后链条的结尾, 要实现 Cancellable
 并且在 cancel 的时候, 触发上游的节点的 cancel 方法.
 */

// 1
final class PausableSubscriber<Input, Failure: Error>:
    Subscriber, Pausable, Cancellable {
    // 2
    let combineIdentifier = CombineIdentifier()
    
    // 3
    let receiveValue: (Input) -> Bool
    // 4
    let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
    
    // 5
    // 存储上游节点.
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
        // 触发上游的节点, 打破循环引用.
        subscription?.cancel()
        subscription = nil
    }
    
    // pipeline 建立的时候, 强引用上级节点.
    func receive(subscription: Subscription) {
        // 9
        self.subscription = subscription
        // 10
        subscription.request(.max(1))
    }
    
    // 每次收到数据之后, 更新需求.
    func receive(_ input: Input) -> Subscribers.Demand {
        // 11
        // 每次, 根据 receiveValue 的返回值, 来判断是否
        paused = receiveValue(input) == false
        // 12
        return paused ? .none : .max(1)
    }
    
    // 收到结束事件的时候, 进行类似的内存清空操作.
    func receive(completion: Subscribers.Completion<Failure>) {
        // 13
        receiveCompletion(completion)
        subscription = nil
    }
    
    func resume() {
        guard paused else { return }
        
        paused = false
        // 14
        // 主动的使用了 subscription 拉取更多的数据.
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
        // 类似于 Sink 的一个操作.
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
