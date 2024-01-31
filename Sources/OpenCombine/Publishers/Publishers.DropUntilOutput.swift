//
//  Publishers.DropUntilOutput.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.12.2019.
//

extension Publisher {

    /// Ignores elements from the upstream publisher until it receives an element from
    /// a second publisher.
    ///
    /// Use `drop(untilOutputFrom:)` to ignore elements from the upstream publisher until
    /// another, second, publisher delivers its first element.
    /// This publisher requests a single value from the second publisher, and it ignores
    /// (drops) all elements from the upstream publisher until the second publisher
    /// produces a value. After the second publisher produces an element,
    /// `drop(untilOutputFrom:)` cancels its subscription to the second publisher, and
    /// allows events from the upstream publisher to pass through.
    ///
    /// After this publisher receives a subscription from the upstream publisher, it
    /// passes through backpressure requests from downstream to the upstream publisher.
    /// If the upstream publisher acts on those requests before the other publisher
    /// produces an item, this publisher drops the elements it receives from the upstream
    /// publisher.
    ///
    /// In the example below, the `pub1` publisher defers publishing its elements until
    /// the `pub2` publisher delivers its first element:
    ///
    ///     let upstream = PassthroughSubject<Int, Never>()
    ///     let second = PassthroughSubject<String, Never>()
    ///     cancellable = upstream
    ///         .drop(untilOutputFrom: second)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     upstream.send(1)
    ///     upstream.send(2)
    ///     second.send("A")
    ///     upstream.send(3)
    ///     upstream.send(4)
    ///     // Prints "3 4"
    ///
    /// - Parameter publisher: A publisher to monitor for its first emitted element.
    /// - Returns: A publisher that drops elements from the upstream publisher until
    ///   the `other` publisher produces a value.
    /// 忽略来自上游发布者的元素，直到它接收到来自第二个发布者的元素。
    ///
    /// 使用 `drop(untilOutputFrom:)` 来忽略来自上游发布者的元素，直到另一个第二个发布者传递其第一个元素。
    /// 此发布者从第二个发布者请求一个值，并忽略（丢弃）从上游发布者接收到的所有元素，直到第二个发布者产生一个值。在第二个发布者产生一个元素后，`drop(untilOutputFrom:)` 取消对第二个发布者的订阅，并允许上游发布者的事件通过。
    ///
    /// 在此发布者从上游发布者接收到订阅之后，它将通过下游对上游发布者的背压请求。如果上游发布者在其他发布者产生项目之前对这些请求做出响应，此发布者将放弃从上游发布者接收到的元素。
    ///
    /// 在下面的示例中，`pub1` 发布者推迟发布其元素，直到 `pub2` 发布者传递其第一个元素：
    ///
    ///     let upstream = PassthroughSubject<Int, Never>()
    ///     let second = PassthroughSubject<String, Never>()
    ///     cancellable = upstream
    ///         .drop(untilOutputFrom: second)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     upstream.send(1)
    ///     upstream.send(2)
    ///     second.send("A")
    ///     upstream.send(3)
    ///     upstream.send(4)
    ///     // 输出 "3 4"
    ///
    /// - Parameter publisher: 要监视其第一个发出元素的发布者。
    /// - Returns: 一个发布者，它会在第二个发布者产生值之前从上游发布者中删除元素。

    public func drop<Other: Publisher>(
        untilOutputFrom publisher: Other
    ) -> Publishers.DropUntilOutput<Self, Other> where Failure == Other.Failure {
        return .init(upstream: self, other: publisher)
    }
}

extension Publishers {

    /// A publisher that ignores elements from the upstream publisher until it receives
    /// an element from second publisher.
    public struct DropUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher
        where Upstream.Failure == Other.Failure
    {
        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A publisher to monitor for its first emitted element.
        public let other: Other

        /// Creates a publisher that ignores elements from the upstream publisher until
        /// it receives an element from another publisher.
        ///
        /// - Parameters:
        ///   - upstream: A publisher to drop elements from while waiting for another
        ///     publisher to emit elements.
        ///   - other: A publisher to monitor for its first emitted element.
        public init(upstream: Upstream, other: Other) {
            self.upstream = upstream
            self.other = other
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input,
                  Other.Failure == Downstream.Failure
        {
            let inner = Inner(downstream: subscriber)
            subscriber.receive(subscription: inner)
            other.subscribe(Inner.OtherSubscriber(inner: inner))
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.DropUntilOutput: Equatable
    where Upstream: Equatable, Other: Equatable {}

extension Publishers.DropUntilOutput {
    fileprivate final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private var triggered = false

        private let lock = UnfairLock.allocate()

        private let downstreamLock = UnfairRecursiveLock.allocate()

        private var upstreamSubscription: Subscription?

        private var pendingDemand = Subscribers.Demand.none

        private var otherSubscription: Subscription?

        private var otherFinished = false

        private var cancelled = false

        init(downstream: Downstream) {
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard upstreamSubscription == nil && !cancelled else {
                lock.unlock()
                subscription.cancel()
                return
            }
            upstreamSubscription = subscription
            if pendingDemand > 0 {
                lock.unlock()
                subscription.request(pendingDemand)
            } else {
                lock.unlock()
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            // 使用来处理上游的数据.
            if !triggered || cancelled {
                pendingDemand -= 1
                lock.unlock()
                return .none
            }
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            return newDemand
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            if cancelled {
                lock.unlock()
                return
            }
            cancelled = true
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }

        private func receiveOther(subscription: Subscription) {
            // Combine doesn't lock here
            guard otherSubscription == nil else {
                subscription.cancel()
                return
            }
            otherSubscription = subscription
            // 只要一个数据.
            subscription.request(.max(1))
        }

        private func receiveOther(_ input: Other.Output) -> Subscribers.Demand {
            lock.lock()
            triggered = true
            // 不对调用 otherSubscription 的 cancel.
            otherSubscription = nil
            lock.unlock()
            return .none
        }

        private func receiveOther(completion: Subscribers.Completion<Other.Failure>) {
            lock.lock()
            if triggered {
                otherSubscription = nil
                lock.unlock()
                return
            }

            // 如果, upstreamSubscription 还没有 trigger, 而 other finish 了, 那就是 upstreamSubscription 永远不会有触发的机会了.
            otherFinished = true
            if let upstreamSubscription = self.upstreamSubscription.take() {
                lock.unlock()
                upstreamSubscription.cancel()
            } else {
                lock.unlock()
            }
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            pendingDemand += demand
            if let subscription = upstreamSubscription {
                lock.unlock()
                subscription.request(demand)
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            let upstreamSubscription = self.upstreamSubscription.take()
            let otherSubscription = self.otherSubscription.take()
            cancelled = true
            lock.unlock()

            upstreamSubscription?.cancel()
            otherSubscription?.cancel()
        }

        var description: String { return "DropUntilOutput" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.DropUntilOutput.Inner {
    fileprivate struct OtherSubscriber
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        let inner: Publishers.DropUntilOutput<Upstream, Other>.Inner<Downstream>

        var combineIdentifier: CombineIdentifier {
            return inner.combineIdentifier
        }

        func receive(subscription: Subscription) {
            inner.receiveOther(subscription: subscription)
        }

        func receive(_ input: Other.Output) -> Subscribers.Demand {
            return inner.receiveOther(input)
        }

        func receive(completion: Subscribers.Completion<Other.Failure>) {
            inner.receiveOther(completion: completion)
        }

        var description: String { return "DropUntilOutput" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
