//
//  Publishers.CollectByCount.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.12.2019.
//

extension Publisher {

    /// Collects up to the specified number of elements, and then emits a single array of
    /// the collection.
    ///
    /// Use `collect(_:)` to emit arrays of at most `count` elements from an upstream
    /// publisher. If the upstream publisher finishes before collecting the specified
    /// number of elements, the publisher sends an array of only the items it received
    /// This may be fewer than `count` elements.
    ///
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    ///
    /// In the example below, the `collect(_:)` operator emits one partial and two full
    /// arrays based on the requested collection size of `5`:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .collect(5)
    ///         .sink { print("\($0), terminator: " "") }
    ///
    ///     // Prints "[0, 1, 2, 3, 4] [5, 6, 7, 8, 9] [10] "
    ///
    /// > Note: When this publisher receives a request for `.max(n)` elements, it requests
    /// `.max(count * n)` from the upstream publisher.
    ///
    /// - Parameter count: The maximum number of received elements to buffer before
    ///   publishing.
    /// - Returns: A publisher that collects up to the specified number of elements, and
    ///   then publishes them as an array.
    /// 收集最多指定数量的元素，然后发出一次包含该集合的数组。
    ///
    /// 使用 `collect(_:)` 从上游发布者发出最多 `count` 个元素的数组。如果上游发布者在收集指定数量的元素之前完成，那么此发布者将发送一个仅包含它收到的项目的数组，这可能少于 `count` 个元素。
    ///
    /// 如果上游发布者以错误失败，此发布者将将错误转发给下游接收器，而不是发送其输出。
    ///
    /// 在下面的示例中，`collect(_:)` 运算符根据请求的集合大小 `5` 发出一个部分数组和两个完整数组：
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .collect(5)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // 输出: "[0, 1, 2, 3, 4] [5, 6, 7, 8, 9] [10] "
    ///
    /// > 注意: 当此发布者收到 `.max(n)` 元素的请求时，它会从上游发布者请求 `.max(count * n)` 元素。
    ///
    /// - Parameter count: 发布之前要缓冲的最大接收元素数。
    /// - Returns: 一个发布者，收集最多指定数量的元素，然后将它们作为数组发布。

    public func collect(_ count: Int) -> Publishers.CollectByCount<Self> {
        return .init(upstream: self, count: count)
    }
}

extension Publishers {

    /// A publisher that buffers a maximum number of items.
    public struct CollectByCount<Upstream: Publisher>: Publisher {

        public typealias Output = [Upstream.Output]

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        ///  The maximum number of received elements to buffer before publishing.
        public let count: Int

        public init(upstream: Upstream, count: Int) {
            self.upstream = upstream
            self.count = count
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber, count: count))
        }
    }
}

extension Publishers.CollectByCount: Equatable where Upstream: Equatable {}

extension Publishers.CollectByCount {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == [Upstream.Output],
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let count: Int

        private var buffer: [Input] = []

        private var subscription: Subscription?

        private var finished = false

        private let lock = UnfairLock.allocate()

        init(downstream: Downstream, count: Int) {
            self.downstream = downstream
            self.count = count
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            if finished || self.subscription != nil {
                lock.unlock()
                subscription.cancel()
                return
            }
            self.subscription = subscription
            lock.unlock()
            downstream.receive(subscription: self)
        }

        // 积累到一定的数量, 然后发送所有的数据.
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            if subscription == nil {
                lock.unlock()
                return .none
            }
            buffer.append(input)
            guard buffer.count == count else {
                lock.unlock()
                return .none
            }
            let output = self.buffer.take()
            lock.unlock()
            // 下游, 会在每次获取到数据的时候, 返回自己的 demand 的值.
            // 也可以, 主动调用上游 Subscription 的 request(_ demand: Subscribers.Demand) 方法, 主动的索取数据. 
            return downstream.receive(output) * count
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            subscription = nil
            finished = true
            switch completion {
            case .finished:
                if buffer.isEmpty {
                    lock.unlock()
                } else {
                    // 最后, 会清空现有的数据.
                    let buffer = self.buffer.take()
                    lock.unlock()
                    _ = downstream.receive(buffer)
                }
            case .failure:
                // 如果发送了错误, 不会发送现有的数据.
                buffer = []
                lock.unlock()
            }
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if let subscription = self.subscription {
                lock.unlock()
                subscription.request(demand * count)
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            if let subscription = self.subscription.take() {
                buffer = []
                finished = true
                lock.unlock()
                subscription.cancel()
            } else {
                lock.unlock()
            }
        }

        var description: String { return "CollectByCount" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("upstreamSubscription", subscription as Any),
                ("buffer", buffer),
                ("count", count)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
