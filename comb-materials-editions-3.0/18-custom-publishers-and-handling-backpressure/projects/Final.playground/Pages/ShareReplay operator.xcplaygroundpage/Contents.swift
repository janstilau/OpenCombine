import Foundation
import Combine

extension Publisher {
    func shareReplay(capacity: Int = .max) -> Publishers.ShareReplay<Self> {
        return Publishers.ShareReplay(upstream: self, capacity: capacity)
    }
}

// 在 Combine 里面, 没有 Replay 这回事. 在这里, 进行自定义.
// 和以往的不同, 这次的 Publisher, 是引用语义的, 它直接进行了响应链的交互.
extension Publishers {
    // 20
    final class ShareReplay<Upstream: Publisher>: Publisher {
        // 21
        typealias Output = Upstream.Output
        typealias Failure = Upstream.Failure
        
        // 22
        private let lock = NSRecursiveLock()
        // 23
        private let upstream: Upstream
        // 24
        private let capacity: Int
        // 25
        // Publihser 缓存数据, 是为了新的 Subscriber 来临的时候, 可以将数据 replay 给新的链路.
        // 这个必须在 Publisher 里面缓存, 因为, ShareReplaySubscription 是后半程链路的维护, 里面的 Replay 数据, 会被各自的 Subscriber Demand 污染.
        // 真正的完整的, 没有被破坏的缓存数据, 其实只应该有一份.
        private var replay = [Output]()
        // 26
        // ???? 这是一个 Publihser, 怎么有这玩意.
        private var subscriptions = [ShareReplaySubscription<Output, Failure>]()
        // 27
        // 存储, 最后的一个值.
        private var completion: Subscribers.Completion<Failure>? = nil
        
        init(upstream: Upstream, capacity: Int) {
            self.upstream = upstream
            self.capacity = capacity
        }
        
        func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure,
              Output == S.Input {
                  lock.lock()
                  defer { lock.unlock() }
                  
                  // 34
                  let subscription = ShareReplaySubscription(
                    subscriber: subscriber,
                    replay: replay,
                    capacity: capacity,
                    completion: completion)
                  
                  // 35
                  subscriptions.append(subscription)
                  // 36
                  subscriber.receive(subscription: subscription)
                  
                  // 37
                  guard subscriptions.count == 1 else { return }
                  // 38
                  let sink = AnySubscriber(
                    // 39
                    receiveSubscription: { subscription in
                        // 40
                        subscription.request(.unlimited)
                    },
                    receiveValue: { [weak self] (value: Output) -> Subscribers.Demand in
                        self?.relay(value)
                        return .none
                    },
                    receiveCompletion: { [weak self] in
                        self?.complete($0)
                    }
                  )
                  
                  // 真正和上游节点交互的, 是这个 Sink 节点.
                  // 这里, Publisher 相当于一个 Subject, 起到了 Dispatch 的作用.
                  upstream.subscribe(sink)
              }
        
        private func relay(_ value: Output) {
            // 28
            lock.lock()
            defer { lock.unlock() }
            
            // 29
            guard completion == nil else { return }
            
            // 30
            replay.append(value)
            if replay.count > capacity {
                replay.removeFirst()
            }
            // 31
            subscriptions.forEach {
                $0.receive(value)
            }
        }
        
        private func complete(_ completion: Subscribers.Completion<Failure>) {
            lock.lock()
            defer { lock.unlock() }
            // 32
            // 存储结束事件, 这对结束后新加入的 Subscriber 有作用.
            self.completion = completion
            // 33
            subscriptions.forEach {
                $0.receive(completion: completion)
            }
        }
    }
}

/*
 ShareReplaySubscription 起到了分发节点的作用. 后续的节点, 都是从该节点获取的数据.
 同样的, 和 Subject 里面的设计一样, 这算是后续节点的起始节点, 所以带有 Demand 的管理.
 */
// 1
fileprivate final class ShareReplaySubscription<Output, Failure: Error>: Subscription {
    // 2
    let capacity: Int
    // 3
    // 这里不能够使用 Subscriber Protocol. 因为这个协议带有 associate type. 所以, 不能够当做类型进行使用, 只能在泛型里面, 当做限制
    // 而在 init 方法里面, 传入的类型其实是可以确认的.
    // 使用 AnySubscriber 进行类型抹除, 不然, 这里的 API 是没有办法书写的.
    var subscriber: AnySubscriber<Output,Failure>? = nil
    // 4
    var demand: Subscribers.Demand = .none
    // 5
    // Subscription 中的 Buffer, 主要是为了尊重 Combine 的 Pull 原型.
    // 因为 Subscription 现在是后半程分发链条的起点, 所以由它来控制下游 Subscriber 的 Demand 需求. 所以, 这个节点要缓存数据, 当下游节点 Demand 需求不足的时候, 存储, 当下游节点 Demand 来临的时候, 将缓存的数据一次性发射出去.
    var buffer: [Output]
    // 6
    var completion: Subscribers.Completion<Failure>? = nil
    
    init<S>(subscriber: S,
            replay: [Output],
            capacity: Int,
            completion: Subscribers.Completion<Failure>?)
    where S: Subscriber,
    Failure == S.Failure,
    Output == S.Input {
        // 7
        // 这里, AnySubscriber 的意义????
        self.subscriber = AnySubscriber(subscriber)
        // 8
        self.buffer = replay
        self.capacity = capacity
        self.completion = completion
    }
    
    private func complete(with completion: Subscribers.Completion<Failure>) {
        // 9
        guard let subscriber = subscriber else { return }
        self.subscriber = nil
        // 10
        self.completion = nil
        self.buffer.removeAll()
        // 11
        subscriber.receive(completion: completion)
    }
    
    private func emitAsNeeded() {
        guard let subscriber = subscriber else { return }
        // 12
        while self.demand > .none && !buffer.isEmpty {
            // 13
            self.demand -= .max(1)
            // 14
            let nextDemand = subscriber.receive(buffer.removeFirst())
            // 15
            if nextDemand != .none {
                self.demand += nextDemand
            }
        }
        
        // 16
        // 先将, 上方的 Next 事件全部交给后方节点.
        // 注意, 这里并不是说 buffer 里面的内容已经发完了, 也可能是后方节点 Demand 的需求已经完毕了.
        // 然后如果有 self.completion, 那就是证明其实上游的分发节点已经结束了, 将结束事件, 也下发给后方节点.
        // 在 complete 里面, 做了各种资源的清理.
        // 这是一个很棒的设计, 缓存的数据, 以及
        if let completion = completion {
            complete(with: completion)
        }
    }
    
    func request(_ demand: Subscribers.Demand) {
        if demand != .none {
            self.demand += demand
        }
        emitAsNeeded()
    }
    
    func receive(_ input: Output) {
        guard subscriber != nil else { return }
        // 17
        buffer.append(input)
        if buffer.count > capacity {
            // 18
            buffer.removeFirst()
        }
        // 19
        emitAsNeeded()
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        guard let subscriber = subscriber else { return }
        self.subscriber = nil
        // 将所有没有发送的数据清空, 整个响应链路已经结束了. 
        self.buffer.removeAll()
        subscriber.receive(completion: completion)
    }
    
    func cancel() {
        // 为什么. 这样不会引起下方节点, 收到一个 Complete Event 吗
        complete(with: .finished)
    }
}


// 41
var logger = TimeLogger(sinceOrigin: true)
// 42
let subject = PassthroughSubject<Int,Never>()
// 43
let publisher = subject
    .print("shareReplay")
    .shareReplay(capacity: 2)
// 44
subject.send(0)

let subscription1 = publisher.sink(
    receiveCompletion: {
        print("subscription1 completed: \($0)", to: &logger)
    },
    receiveValue: {
        print("subscription1 received \($0)", to: &logger)
    }
)

subject.send(1)
subject.send(2)
subject.send(3)

let subscription2 = publisher.sink(
    receiveCompletion: {
        print("subscription2 completed: \($0)", to: &logger)
    },
    receiveValue: {
        print("subscription2 received \($0)", to: &logger)
    }
)

subject.send(4)
subject.send(5)
subject.send(completion: .finished)

var subscription3: Cancellable? = nil

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    print("Subscribing to shareReplay after upstream completed")
    subscription3 = publisher.sink(
        receiveCompletion: {
            print("subscription3 completed: \($0)", to: &logger)
        },
        receiveValue: {
            print("subscription3 received \($0)", to: &logger)
        }
    )
}
