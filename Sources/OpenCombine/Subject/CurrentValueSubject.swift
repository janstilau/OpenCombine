/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.

/// Unlike `PassthroughSubject`, `CurrentValueSubject` maintains a buffer of the most
/// recently published element.

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
    // 在 Subject 接收到上游的结束事件的时候, 会将这个值进行存储.
    // 后续新的 Subscriber 来临的时候, 可以直接收到这个存储的事件.
    private var completion: Subscribers.Completion<Failure>?
    
    // 存储一下, 上游节点. 上游节点, 只会在 Deinit 的时候, 对于所有的上游节点进行 cancel.
    // 一个 Subject 对象, 可能会有很多的上游节点. 因为, 可能会有很多的信号, 触发 Object 的修改.
    // 一个 Subject 对象, 可能会有很多的下游节点. 每次自己修改之后, 都会把修改信号, 发送给所有的下游节点. 
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
    
    private func sendValueAndConsumeLock(_ newValue: Output) {
        // 必须要做这样的判断. 因为 Subject 的各个函数, 其实是手动触发的.
        // 如果使用者 sendComplete 之后, 又进行了 send value, 其实有可能的. 业务逻辑复杂了之后, 类的设计者应该保证自己类的健壮性.
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
    
    // CurrentObject, 一定是初始化的时候, 提供值.
    public init(_ value: Output) {
        self.currentValue = value
    }
    
    deinit {
        // 要记住, 每个响应链条都是独立的. Subject Deinit 触发了上游链条的 cancel. 但是也是和自己相关的那个链条.
        // 哪怕是共享链条, 也仅仅是在 dispatch 的节点里面, 将自己所在的链条, 从节点的分发存储中进行了删除而已.
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
        // 存储所有的上游节点. upstreamSubscriptions 在类内没有业务逻辑, 主要是为了在 Subject deinit 的时候, 进行上游节点的 cancel 处理.
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        
        /*
         Subject, 是一个分发器. 可以认为它是一段相应链条的终点.
         它所管理的几条后续链条, 它所管理的 ConduiteList 是各个链条的起始节点, 在这些节点里面, 进行了 Demand 的管理.
         作为上一段链条的终点, 它不做 Demand 管理, 上游 Publisher 的 Next 事件全部接受.
         但是转发个给下游节点的时候, 根据 Demand 进行的发送.
         */
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
    
    // 不论, Subject 作为多少条链条的终止节点, 只要有一条发送了 Completion, 都结束.
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
        // 这里有强引用.
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
        
        // 上游节点, 发送数据过来之后, forward 给下游节点.
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
