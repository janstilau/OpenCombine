import Combine

fileprivate final class ShareReplaySubscription<Output, Failure>: Subscription
where Failure: Error {
    let capacity: Int
    var subscriber: AnySubscriber<Output,Failure>? = nil
    var demand: Subscribers.Demand = .none
    var buffer: [Output]
    var completion: Subscribers.Completion<Failure>? = nil
    
    init<S>(subscriber: S,
            replay: [Output],
            capacity: Int,
            completion: Subscribers.Completion<Failure>?)
    where S: Subscriber,
    Failure == S.Failure,
    Output == S.Input {
        self.subscriber = AnySubscriber(subscriber)
        self.buffer = replay
        self.capacity = capacity
        self.completion = completion
    }
    
    private func complete(with completion: Subscribers.Completion<Failure>) {
        guard let subscriber = subscriber else { return }
        self.subscriber = nil
        self.completion = nil
        self.buffer.removeAll()
        subscriber.receive(completion: completion)
    }
    
    private func emitAsNeeded() {
        guard let subscriber = subscriber else { return }
        while self.demand > .none && !buffer.isEmpty {
            self.demand -= .max(1)
            let nextDemand = subscriber.receive(buffer.removeFirst())
            if nextDemand != .none {
                self.demand += nextDemand
            }
        }
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
    
    func cancel() {
        complete(with: .finished)
    }
    
    func receive(_ input: Output) {
        guard subscriber != nil else { return }
        buffer.append(input)
        if buffer.count > capacity {
            buffer.removeFirst()
        }
        emitAsNeeded()
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        guard let subscriber = subscriber else { return }
        self.subscriber = nil
        self.buffer.removeAll()
        subscriber.receive(completion: completion)
    }
}

extension Publishers {
    final class ShareReplay<Upstream: Publisher>: Publisher {
        typealias Output = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let lock = NSRecursiveLock()
        private let upstream: Upstream
        private let capacity: Int
        private var replay = [Output]()
        private var subscriptions = [ShareReplaySubscription<Output, Failure>]()
        private var completion: Subscribers.Completion<Failure>? = nil
        
        init(upstream: Upstream, capacity: Int) {
            self.upstream = upstream
            self.capacity = capacity
        }
        
        private func relay(_ value: Output) {
            lock.lock()
            defer { lock.unlock() }
            if completion == nil {
                replay.append(value)
                if replay.count > capacity {
                    replay.removeFirst()
                }
                subscriptions.forEach {
                    $0.receive(value)
                }
            }
        }
        
        private func complete(_ completion: Subscribers.Completion<Failure>) {
            lock.lock()
            self.completion = completion
            subscriptions.forEach {
                $0.receive(completion: completion)
            }
            lock.unlock()
        }
        
        func receive<S>(subscriber: S)
        where S : Subscriber,
              Failure == S.Failure,
              Output == S.Input {
                  lock.lock()
                  defer { lock.unlock() }
                  let subscription = ShareReplaySubscription(
                    subscriber: subscriber,
                    replay: replay, capacity: capacity,
                    completion: completion
                  )
                  subscriptions.append(subscription)
                  subscriber.receive(subscription: subscription)
                  
                  guard subscriptions.count == 1 else { return }
                  let sink = AnySubscriber(
                    receiveSubscription: { subscription in
                        subscription.request(.unlimited)
                    },
                    receiveValue: { [weak self] (value: Output) -> Subscribers.Demand in
                        self?.relay(value)
                        return .none
                    },
                    receiveCompletion: { [weak self] in
                        self?.complete($0)
                    })
                  upstream.subscribe(sink)
              }
    }
}

extension Publisher {
    // 自己定义的一个 Operator.
    func shareReplay(capacity: Int = Int.max) -> Publishers.ShareReplay<Self> {
        return Publishers.ShareReplay(upstream: self, capacity: capacity)
    }
}
