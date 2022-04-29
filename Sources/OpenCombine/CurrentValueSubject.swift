/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.
///
/// Unlike `PassthroughSubject`, `CurrentValueSubject` maintains a buffer of the most
/// recently published element.

// 对于 CurrentValueSubject 来说, send 和 赋值操作, 是一个操作后果.
/// Calling `send(_:)` on a `CurrentValueSubject` also updates the current value, making
/// it equivalent to updating the `value` directly.

/*
 Subject 的实现, 和 Rx 差不多.
 最重要的是, 这是一个可以缓存多个下游节点的节点.
 Combine 里面, 增加了 Demand 的管理, 所以 Combine 中的 dispatchNode 要复杂一些.
 */
public final class CurrentValueSubject<Output, Failure: Error>: Subject {
    
    private let lock = UnfairLock.allocate()
    
    private var active = true
    
    // 存储一下结束事件.
    // 在 Subject 接收到上游的结束事件的时候, 会将这个值进行复制. 后续新的 Subscriber 来临的时候, 可以直接收到这个存储的事件.
    private var completion: Subscribers.Completion<Failure>?
    
    // 存储一下, 上游节点. 上游节点, 只会在 Deinit 的时候, 对于所有的上游节点进行 cancel.
    private var upstreamSubscriptions: [Subscription] = []
    
    // 所以, 实际上, Subject 是天然的分发器.
    // 存储一下, 下游节点. 没有直接存储 Subsriber, 而是一个 Conduit 对象
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
    
    // CurrentObject, 一定是初始化的时候, 提供值.
    public init(_ value: Output) {
        self.currentValue = value
    }
    
    // 和 Rx 不同的是, Combine 里面, 对象的声明周期, 和 cancel 有了强绑定的关系.
    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }
    
    /*
     上游节点, 发送 Subscription 过来, 记录在自己缓存区里面.
     */
    public func send(subscription: Subscription) {
        lock.lock()
        // 存储所有的上游节点.
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        
        // Subject, 对于上游节点的数据, 是来者不拒的.
        // 但是, 他内部会管理所有的后续节点的 Demand 需求.
        // 当, 上游节点发布数据到 Subject 之后, 会分发到 conduit 里面, 在每个 conduit 里面, 会进行 Demand 的管理.
        subscription.request(.unlimited)
    }
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        lock.lock()
        if active {
            // 当, 发送了 Completion 事件之后, 才会
            let conduit = Conduit(parent: self, downstream: subscriber)
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
        } else {
            // 如果, 当前自己已经 cancel 过了, 直接交给后方 stopEvent.
            let completion = self.completion!
            lock.unlock()
            // 一定要给后续的节点, 发送一个 subscription. 因为并不知道, 后续节点, 会根据这个做什么处理.
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }
    
    public func send(_ input: Output) {
        lock.lock()
        sendValueAndConsumeLock(input)
    }
    
    // 如果, 已经结束了, 新的 Send 指令一点效果都没有
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
        // 记录一下 Completion, 之后的 subscriber 可以直接使用.
        // active 和 completion 是绑定在一起的, 可以使用一个 Enum 来进行管理.
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
        // 解除 Subject 和下游节点的关联关系.
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
        
        // 在每个 Conduit 里面, 记录下游节点. 当上游节点发送数据过来的时候, 交给各个 Conduit 传递给后续节点上.
        fileprivate var downstream: Downstream?
        // 记录下游节点, 对于自己的需求.
        fileprivate var demand = Subscribers.Demand.none
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        // 记录, 当前自己是否可以向后传递的状态.
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
        
        // 上游节点, 发送数据过来之后, 是调用 Offer 函数.
        // 在这个函数内, 有着 Demand 的管理策略.
        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            // demand 的管理.
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            // 给下游节点喂食.
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            // demand 的管理.
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
            // 下游节点, 接收到 完成事件.
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
                // 管理 Demand 的值.
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
                // 如果, 后续节点要值了, 那么主动的发送一下当前的值过去.
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
