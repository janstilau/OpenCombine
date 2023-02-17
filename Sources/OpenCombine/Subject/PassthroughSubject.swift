/// A subject that broadcasts elements to downstream subscribers.

/// As a concrete implementation of `Subject`, the `PassthroughSubject` provides
/// a convenient way to adapt existing imperative code to the Combine model.
// 从这里可以看出, Subject 一大作用, 就是命令式到响应式的迁移.

/// Unlike `CurrentValueSubject`, a `PassthroughSubject` doesn’t have an initial value or
/// a buffer of the most recently-published element.
/// A `PassthroughSubject` drops values if there are no subscribers, or its current demand
/// is zero.

/*
 Subject 的使用场景.
 1. 多路分发. 各种 Share 的语义, 最终都是使用 Subject 实现的.
 2. 原有代码迁移到 Combine 中.
 */
public final class PassthroughSubject<Output, Failure: Error>: Subject {
    private let internalLock = UnfairLock.allocate()
    
    // 这个 active 其实和 completionEvent 重叠了, 目前来说, completionEvent 有值的时候, active 一定改为 false.
    private var active = true
    
    // 数据值, 结束事件.
    private var completionEvent: Subscribers.Completion<Failure>?
    
    // 存储, 所有的下游节点. 这是 Subject 可以作为分发器的原因.
    private var downstreams = ConduitList<Output, Failure>.empty
    // 存储, 所有的上游节点, 这是 Subject 可以作为多次作为 Subscriber 的原因.
    // Subscription 是一个接口对象.
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
        internalLock.deallocate()
    }
    
    /*
     Subject 这里的 Demand 管理出现了一个问题.
     一般来说, 我们使用 Subject 是将它用作 Origin Publisher 来使用, 但是它确实可以包装成为 SubjectSubscriber, 成为下游节点.
     Subject 作为一个 Funnel, 承担了所有的上游的数据, 然后将所有数据发送给所有的下游.
     当它作为 Funnel 的时候, 是在自己内部管理了下游节点的 Demand, 自己还是当做这些下游节点的 Origin 来使用, 但是对于上游来说, 则是 Unlimit 的索取.
     */
    
    // 当 Subject 作为一个新的通路终点的时候, 会触发到这里.
    public func send(subscription: Subscription) {
        internalLock.lock()
        // 循环引用
        upstreamSubscriptions.append(subscription)
        let hasAnyDownstreamDemand = self.hasAnyDownstreamDemand
        internalLock.unlock()
        // 代表着下游已经要数据了, 新进来的上游被无限进行索取.
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }
    
    // 如果, 没有接受过结束事件. 那么就将 Subscriber 存储到自己的 downstreams 中.
    // 如果, 已经接受过结束事件. 那么就将结束事件, 传递给新的 subscriber.
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        internalLock.lock()
        if active {
            let conduit = Conduit(parent: self, downstream: subscriber)
            downstreams.insert(conduit)
            internalLock.unlock()
            // 这里会引起循环引用.
            subscriber.receive(subscription: conduit)
        } else {
            // 这里有点 promise 的感觉, 如果已经有了 completionEvent 就直接将向下游发送, 这个时候, 其实不用存储下游到自己的成员变量里面.
            let completion = self.completionEvent!
            internalLock.unlock()
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }
    
    public func send(_ input: Output) {
        internalLock.lock()
        /*
         Subject 本身可能是作为 Subscriber 来使用的.
         所以可能会是多个链条中的一环. 如果其中一条发送了 completion 事件, 那么这个 Subject 就应该是 Completion 的状态.
         Subject 可以认为是一个 Funnel, 自己管理者多个下游, 将上游的数据, 分发给所有的下游.
         */
        guard active else {
            internalLock.unlock()
            return
        }
        // 当, 接收到上游的 Next 事件, 会将给所有的后续节点, 进行分发的操作.
        // 从这里可以看出, Subject 作为分发器的基础, 就是他存储了所有的 Subscriber 对象了.
        let downstreams = self.downstreams
        internalLock.unlock()
        // 自己接受到改变之后, 向下游进行值的传递.
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
        internalLock.lock()
        guard active else {
            internalLock.unlock()
            return
        }
        active = false
        self.completionEvent = completion
        // Take 就是有着释放资源的含义.
        let downstreams = self.downstreams.take()
        internalLock.unlock()
        downstreams.forEach { conduit in
            conduit.finish(completion: completion)
        }
    }
    
    /*
     Subject 作为一个
     */
    private func acknowledgeDownstreamDemand() {
        internalLock.lock()
        if hasAnyDownstreamDemand {
            internalLock.unlock()
            return
        }
        hasAnyDownstreamDemand = true
        let upstreamSubscriptions = self.upstreamSubscriptions
        internalLock.unlock()
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
        }
    }
    
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        internalLock.lock()
        guard active else {
            internalLock.unlock()
            return
        }
        downstreams.remove(conduit)
        internalLock.unlock()
    }
}

// 每一个具有多路分发的 Funnel 节点里面, 都有着 Conduit 的类型的存在.
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
        
        fileprivate var demand = Subscribers.Demand.none // 每个 demand 分别管理.
        
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
        
        // 当发送了完毕信号之后, 这里其实有着生命周期的关闭.
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
