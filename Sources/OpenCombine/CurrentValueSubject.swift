
/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.
///
/// Unlike `PassthroughSubject`, `CurrentValueSubject` maintains a buffer of the most
/// recently published element.
///
/// Calling `send(_:)` on a `CurrentValueSubject` also updates the current value, making
/// it equivalent to updating the `value` directly.

/// 一个主题（Subject），包装单个值，并在该值更改时发布新元素。
///
/// 与 `PassthroughSubject` 不同，`CurrentValueSubject` 保持最近发布的元素的缓冲区。
///
/// 在 `CurrentValueSubject` 上调用 `send(_:)` 也会更新当前值，相当于直接更新 `value`。
public final class CurrentValueSubject<Output, Failure: Error>: Subject {
    
    private let lock = UnfairLock.allocate()
    
    private var active = true
    
    private var completion: Subscribers.Completion<Failure>?
    
    private var downstreams = ConduitList<Output, Failure>.empty
    
    private var currentValue: Output
    
    private var upstreamSubscriptions: [Subscription] = []
    
    // 和 PassThrough 没有太多的区别, 只不过, 比如要有一个 Value 的值.
    /// The value wrapped by this subject, published as a new element whenever it changes.
    public var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentValue
        }
        set {
            lock.lock()
            currentValue = newValue
            // 之所以, 需要把 currentValue 包装成为 value, 就是为了这里.
            sendValueAndConsumeLock(newValue)
        }
    }
    
    /// Creates a current value subject with the given initial value.
    ///
    /// - Parameter value: The initial value to publish.
    public init(_ value: Output) {
        self.currentValue = value
    }
    
    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }
    
    public func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        
        // 不需要下游主动 request.
        subscription.request(.unlimited)
    }
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        lock.lock()
        if active {
            let conduit = Conduit(parent: self, downstream: subscriber)
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
        } else {
            let completion = self.completion!
            lock.unlock()
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }
    
    public func send(_ input: Output) {
        lock.lock()
        sendValueAndConsumeLock(input)
    }
    
    // ConsumeLock, 明确的表明了, 里面要进行 unlock 的操作.
    private func sendValueAndConsumeLock(_ newValue: Output) {
#if DEBUG
        lock.assertOwner()
#endif
        guard active else {
            lock.unlock()
            return
        }
        currentValue = newValue
        let downstreams = self.downstreams
        lock.unlock()
        downstreams.forEach { conduit in
            conduit.offer(newValue)
        }
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        self.completion = completion
        let downstreams = self.downstreams.take()
        lock.unlock()
        downstreams.forEach { conduit in
            conduit.finish(completion: completion)
        }
    }
    
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension CurrentValueSubject {
    
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        
        fileprivate var parent: CurrentValueSubject?
        
        fileprivate var downstream: Downstream?
        
        fileprivate var demand = Subscribers.Demand.none
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        // 这个值用来控制, 当前上游的数值, 是否已经被下游消耗了
        // 上游给了, 下游要了, 两个因素共同控制这个. 
        private var deliveredCurrentValue = false
        
        fileprivate init(parent: CurrentValueSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            
            lock.lock()
            demand += newDemand
            lock.unlock()
        }
        
        override func finish(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard let downstream = self.downstream.take() else {
                lock.unlock()
                return
            }
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
        
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            if deliveredCurrentValue {
                self.demand += demand
                lock.unlock()
                return
            }
            
            // Hasn't yet delivered the current value
            
            self.demand += demand
            deliveredCurrentValue = true
            if let currentValue = self.parent?.value {
                self.demand -= 1
                lock.unlock()
                downstreamLock.lock()
                let newDemand = downstream.receive(currentValue)
                downstreamLock.unlock()
                guard newDemand > 0 else { return }
                lock.lock()
                self.demand += newDemand
            }
            lock.unlock()
        }
        
        override func cancel() {
            lock.lock()
            if downstream.take() == nil {
                lock.unlock()
                return
            }
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }
        
        var description: String { return "CurrentValueSubject" }
        
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", downstream as Any),
                ("demand", demand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
