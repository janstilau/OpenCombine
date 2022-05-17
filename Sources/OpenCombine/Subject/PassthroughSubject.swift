/// A subject that broadcasts elements to downstream subscribers.

/// As a concrete implementation of `Subject`, the `PassthroughSubject` provides
/// a convenient way to adapt existing imperative code to the Combine model.

/// Unlike `CurrentValueSubject`, a `PassthroughSubject` doesn’t have an initial value or
/// a buffer of the most recently-published element.
/// A `PassthroughSubject` drops values if there are no subscribers, or its current demand
/// is zero.

/*
 Subject 的使用场景.
 1. 多路分发.
 2. 原有代码迁移到 Combine 中.
 */
/*
 PassthroughSubject  和 CurrentValueSubject 没有太大的区别.
 */
public final class PassthroughSubject<Output, Failure: Error>: Subject {
    private let lock = UnfairLock.allocate()
    
    private var active = true
    
    // 存储结束事件, 主要是给新来的 Subscriber 使用的.
    private var completionEvent: Subscribers.Completion<Failure>?
    
    // 存储, 所有的下游节点. 这是 Subject 可以作为分发器的原因.
    private var downstreams = ConduitList<Output, Failure>.empty
    // 存储, 所有的上游节点, 这是 Subject 可以作为多次作为 Subscriber 的原因.
    internal var upstreamSubscriptions: [Subscription] = []
    
    internal var hasAnyDownstreamDemand = false
    
    public init() {}
    /*
     当, Subject 消亡的时候, 是将自己所有的作为终点的通路进行了消亡.
     这是没有问题的.
     1. 如果这个响应通路没有分发, 只有最后一个 Subject 作为 Subscriber. 那么这条通路就应该消失.
     2. 如果上游节点有着分发的节点, 那么 cancel 到达这里, 也仅仅是进行分发节点的删除而已.
     */
    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }

    // 当 Subject 作为一个新的通路终点的时候, 会触发到这里.
    // 将上游节点进行存储. 如果
    public func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        let hasAnyDownstreamDemand = self.hasAnyDownstreamDemand
        lock.unlock()
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }
    
    // 如果, 没有接受过结束事件. 那么就将 Subscriber 存储到自己的 downstreams 中.
    // 如果, 已经接受过结束事件. 那么就将结束事件, 传递给新的 subscriber.
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
            let completion = self.completionEvent!
            lock.unlock()
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }
    
    public func send(_ input: Output) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        // 当, 接收到上游的 Next 事件, 会将给所有的后续节点, 进行分发的操作.
        // 从这里可以看出, Subject 作为分发器的基础, 就是他存储了所有的 Subscriber 对象了.
        let downstreams = self.downstreams
        lock.unlock()
        downstreams.forEach { conduit in
            conduit.offer(input)
        }
    }

    /*
     当任意的一个上游节点, 发送了结束事件之后, 都会让整个 Subject 处于结束的事件.
     从这里可以看出, downstreams 在这里就被释放了.
     
     这里可能会出现状态不一致的问题, 就是 Subject 作为通路中的一环, 可能因为其他的通路, 导致当前通路的结束.
     如果出现了问题, 可以在这里梳理一下.
     */
    public func send(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        self.completionEvent = completion
        // Take 就是有着释放资源的含义.
        let downstreams = self.downstreams.take()
        lock.unlock()
        downstreams.forEach { conduit in
            conduit.finish(completion: completion)
        }
    }
    
    // 还是尊重了, Combine 的 Pull 原因.
    // Subject 只有接受到后方的要求之后, 才会向前进行申请.
    // 是所有的上方节点, 无限申请.
    private func acknowledgeDownstreamDemand() {
        lock.lock()
        if hasAnyDownstreamDemand {
            lock.unlock()
            return
        }
        hasAnyDownstreamDemand = true
        let upstreamSubscriptions = self.upstreamSubscriptions
        lock.unlock()
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
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

extension PassthroughSubject {
    
    /*
     Subject 作为分发器的基础. 把后续的每一条连续, 都进行了存储.
     Subject 作为每一条连续的头结点, 当 Subject 接受到任何事件的时候, 移交给后续.
     */
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        
        fileprivate var parent: PassthroughSubject?
        
        fileprivate var downstream: Downstream?
        
        fileprivate var demand = Subscribers.Demand.none
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate init(parent: PassthroughSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 在 Subject 的分发线路中, 头结点有着 Demand 管理的含义在.
        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                lock.unlock()
                return
            }
            demand -= 1
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
            if self.downstream == nil {
                lock.unlock()
                return
            }
            self.demand += demand
            let parent = self.parent
            lock.unlock()
            parent?.acknowledgeDownstreamDemand()
        }
        
        /*
         Conduit 和 downstream 之间有循环引用.
         Conduit 还被 PassThroughSubject 强引用着.
         
         cancel, 打破了循环引用, 取消了 PassThroughSubject 的强引用. 
         */
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
        
        var description: String { return "PassthroughSubject" }
        
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
