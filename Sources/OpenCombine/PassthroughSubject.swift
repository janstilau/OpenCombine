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
 他可以有无数的上游, 也可以有无数的下游.
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
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }

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
