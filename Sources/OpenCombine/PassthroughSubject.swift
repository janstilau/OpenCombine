/// A subject that broadcasts elements to downstream subscribers.
///
/// As a concrete implementation of `Subject`, the `PassthroughSubject` provides
/// a convenient way to adapt existing imperative code to the Combine model.
///
/// Unlike `CurrentValueSubject`, a `PassthroughSubject` doesn’t have an initial value or
/// a buffer of the most recently-published element.
/// A `PassthroughSubject` drops values if there are no subscribers, or its current demand
/// is zero.

/// 一个向下游订阅者广播元素的主题（Subject）。
///
/// 作为 `Subject` 的具体实现，`PassthroughSubject` 提供了一种将现有命令式代码适应 Combine 模型的便捷方式。
///
/// 与 `CurrentValueSubject` 不同，`PassthroughSubject` 没有初始值或最近发布的元素的缓冲区。
/// 如果没有订阅者，或者其当前需求为零，`PassthroughSubject` 将丢弃值。

/*
 Subject 是一个多对多的关系.
 他可以有无数的上游, 也可以有无数的下游. 所以, Subject 天然是一个中心的 Pivot 节点. 
 */
public final class PassthroughSubject<Output, Failure: Error>: Subject {

    private let lock = UnfairLock.allocate()

    private var active = true

    private var completion: Subscribers.Completion<Failure>?

    private var downstreams = ConduitList<Output, Failure>.empty

    internal var upstreamSubscriptions: [Subscription] = []

    internal var hasAnyDownstreamDemand = false

    public init() {}

    deinit {
        // Subject 作为 Subscriber, 其实也是弱引用.
        // 所以, 它的生命周期, 完全是自己控制的.
        // 它销毁的时候, 将上游的 Subscriptions 进行 cancel.
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }

    // Subject 一般, 不作为 Subscriber. 如果作为 Subscriber 会被包装起来.
    // 这个时候 ,Subject 就会有 upstreamSubscriptions
    // 从 upstreamSubscriptions 的实现来看, 他的上游, 也是多路的.
    public func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        let hasAnyDownstreamDemand = self.hasAnyDownstreamDemand
        lock.unlock()
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        lock.lock()
        if active {
            // 每当, Subject 接收到一个下游 subscriber 其实是使用了一个 Conduit 当做了 Subscription.
            let conduit = Conduit(parent: self, downstream: subscriber)
            downstreams.insert(conduit)
            lock.unlock()
            // 下游传递过去的 subscription, 是 Subject Pivot 里面的一个节点.
            subscriber.receive(subscription: conduit)
        } else {
            // 如果, 自己已经结束了, 直接给下游传递 compete 的事件.
            let completion = self.completion!
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
        let downstreams = self.downstreams
        lock.unlock()
        downstreams.forEach { conduit in
            conduit.offer(input)
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

    private func acknowledgeDownstreamDemand() {
        lock.lock()
        if hasAnyDownstreamDemand {
            lock.unlock()
            return
        }
        hasAnyDownstreamDemand = true
        let upstreamSubscriptions = self.upstreamSubscriptions
        lock.unlock()
        // Subject 对于上游的 request, 是 unlimited
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

    // 管道，导管；渠道，通道；（保护线路的）导线管，电缆沟
    // Conduit 是一个 Subscription, 所以它的主要的功能, 是承担下游的 Request Deamnd, 和 Cancel 事件.
    // 而上游的事件, 则是 Subject 主动 send, 或者 Subject 承担上游的事件.
    private final class Conduit<Downstream: Subscriber>
        : ConduitBase<Output, Failure>,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Failure
    {

        fileprivate var parent: PassthroughSubject?

        fileprivate var downstream: Downstream? // 真正的 Subject 的节点.

        fileprivate var demand = Subscribers.Demand.none // Conduit 自己管理自己这条链路的 Demand .

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

        // Subject 传递数据, 给下游的节点.
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
            // 在这里, 清除了对于下级节点的引用.
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
