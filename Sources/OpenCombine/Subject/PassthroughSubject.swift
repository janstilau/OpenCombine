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
            // 如果当前 Subject 还正在起作用, 将下游产生的 Subscription 记录起来.
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
        // 这里还是有一个下游的完结事件的发送.
        downstreams.forEach { conduit in
            conduit.finish(completion: completion)
        }
    }
    
    /*
     只有当 Subject 后续有明确的 Demand 的需求的时候, 才进行上游的拉取.
     */
    private func acknowledgeDownstreamDemand() {
        internalLock.lock()
        if hasAnyDownstreamDemand {
            internalLock.unlock()
            return
        }
        // 最主要的就是进行标记量的改变, 然后向之前存储的上游进行 Demand 拉取.
        // 在之后有新的上游挂钩的时候, 会立即进行上游 demand 的申请.
        hasAnyDownstreamDemand = true
        let upstreamSubscriptions = self.upstreamSubscriptions
        internalLock.unlock()
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
        }
    }
    
    // 当下游的分发节点, cancel 或者 complete 的时候, 会通知 Subject 进行下游节点的管理.
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
        
        fileprivate var downstream: Downstream? // 这个是一个 Optinal, 所以才可以使用 take.
        
        fileprivate var demand = Subscribers.Demand.none // 每个 demand 分别管理.
        
        private var conduitLock = UnfairLock.allocate()
        
        /*
         这个 downstreamLock 是每次下游节点接收到新的事件的时候使用的, 而不是 Conduit 中的内部状态修改的时候使用的.
         这样, 下游的节点就算不加锁也没有问题.
         这个锁下游不会得到, 所以不会出现死锁的.
         */
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate init(parent: PassthroughSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            conduitLock.deallocate()
            downstreamLock.deallocate()
        }
        
        // Subject send 值之后, 会将 value 传递到 conduit 节点.
        override func offer(_ output: Output) {
            // 内部数据的修改, 使用 conduitLock 进行锁住.
            conduitLock.lock()
            guard demand > 0,
                  let downstream = self.downstream else {
                conduitLock.unlock()
                return
            }
            
            demand -= 1
            conduitLock.unlock() // 内部状态改变结束后, 尽快的进行锁的释放.
            
            // 下游的节点, 接收事件, 使用专门的 downstreamLock 进行保护.
            downstreamLock.lock()
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            
            guard newDemand > 0 else { return }
            // 在修改 conduit 内部数据数据的时候, 使用 conduitLock 进行锁住.
            conduitLock.lock()
            demand += newDemand
            conduitLock.unlock()
        }
        
        // 当发送了完毕信号之后, 这里其实有着生命周期的关闭.
        override func finish(completion: Subscribers.Completion<Failure>) {
            conduitLock.lock()
            
            // 这里使用 take, 会直接进行 downstream 的替换.
            //
            guard let downstream = self.downstream.take() else {
                conduitLock.unlock()
                return
            }
            // parent 在这里进行了释放.
            let parent = self.parent.take()
            conduitLock.unlock()
            
            parent?.disassociate(self)
            
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
        
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            conduitLock.lock()
            if self.downstream == nil {
                conduitLock.unlock()
                return
            }
            
            self.demand += demand
            let parent = self.parent
            conduitLock.unlock()
            parent?.acknowledgeDownstreamDemand()
        }
        
        /*
         Conduit 和 downstream 之间有循环引用.
         Conduit 还被 PassThroughSubject 强引用着.
         
         cancel, 打破了循环引用, 取消了 PassThroughSubject 的强引用.
         */
        override func cancel() {
            conduitLock.lock()
            if downstream.take() == nil {
                conduitLock.unlock()
                return
            }
            let parent = self.parent.take()
            conduitLock.unlock()
            parent?.disassociate(self)
        }
        
        
        
        
        var description: String { return "PassthroughSubject" }
        
        var customMirror: Mirror {
            conduitLock.lock()
            defer { conduitLock.unlock() }
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
