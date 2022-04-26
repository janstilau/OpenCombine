/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.
///
/// Unlike `PassthroughSubject`, `CurrentValueSubject` maintains a buffer of the most
/// recently published element.
///
/// Calling `send(_:)` on a `CurrentValueSubject` also updates the current value, making
/// it equivalent to updating the `value` directly.

public final class CurrentValueSubject<Output, Failure: Error>: Subject {
    
    private let lock = UnfairLock.allocate()
    
    private var active = true
    
    // 存储一下结束事件.
    private var completion: Subscribers.Completion<Failure>?
    
    // 存储一下, 上有节点.
    private var upstreamSubscriptions: [Subscription] = []
    
    // 存储一下, 下游节点.
    private var downstreams = ConduitList<Output, Failure>.empty
    
    // 缓存一下当前值.
    // 在 Init 的时候, 必须带一个 Output 的值过来.
    private var currentValue: Output
    
    /// The value wrapped by this subject, published as a new element whenever it changes.
    public var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            // 取值, 必须在锁的环境
            return currentValue
        }
        set {
            lock.lock()
            // 赋值, 必须在锁的环境, 并且触发后续的信号发送.
            currentValue = newValue
            sendValueAndConsumeLock(newValue)
        }
    }
    
    /// Creates a current value subject with the given initial value.
    ///
    /// - Parameter value: The initial value to publish.
    public init(_ value: Output) {
        self.currentValue = value
    }
    
    // 和 Rx 不同的是, Combine 里面, 对象的声明周期, 和 cancel 有了强绑定的关系.
    deinit {
        // 按照 rx 里面的设计理念, 上层节点是 shared, 那么这里的 cancel 其实就是做相关的取消注册的工作.
        // 如果, 是单独成链, 那么取消上级也合理.
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }
    
    public func send(subscription: Subscription) {
        lock.lock()
        // 存储所有的上游节点.
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        // 然后, 将 demand 管理成为无限.
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
            // 如果, 当前自己已经 cancel 过了, 直接交给后方 stopEvent.
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
    
    private func sendValueAndConsumeLock(_ newValue: Output) {
        guard active else {
            lock.unlock()
            return
        }
        currentValue = newValue
        let downstreams = self.downstreams
        lock.unlock()
        // 先取出所有的下游节点, 然后就 unlock
        // 因为给下游节点喂食, 可能会引发各种后续操作, 时间不可控的.
        // 当, CurrentValue 发生变化的时候, 给所有的下游节点喂食.
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
            // 给下游节点喂食.
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
        
        // Request, 可以算作是, 下游节点, 触发上游节点逻辑的起点.
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
