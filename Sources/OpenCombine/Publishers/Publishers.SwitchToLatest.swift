// switch to laster 是由要求的, 就是 output 是一个 Publisher.
extension Publisher where Output: Publisher, Output.Failure == Failure {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// For example, given the type `AnyPublisher<URLSession.DataTaskPublisher, NSError>`,
    /// calling `switchToLatest()` results in the type
    /// `SwitchToLatest<(Data, URLResponse), URLError>`.
    /// The downstream subscriber sees a continuous stream of `(Data, URLResponse)`
    /// elements from what looks like a single `URLSession.DataTaskPublisher` even though
    /// the elements are coming from different upstream publishers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    ///
    /// The following example updates a `PassthroughSubject` with a new value every
    /// `0.1` seconds. A `map(_:)` operator receives the new value and uses it to create
    /// a new `URLSession.DataTaskPublisher`. By using the `switchToLatest()` operator,
    /// the downstream sink subscriber receives the `(Data, URLResponse)` output type from
    /// the data task publishers, rather than the `URLSession.DataTaskPublisher` type
    /// produced by the `map(_:)` operator. Furthermore, creating each new data task
    /// publisher cancels the previous data task publisher.
    ///
    ///     let subject = PassthroughSubject<Int, Never>()
    ///     cancellable = subject
    ///         .setFailureType(to: URLError.self)
    ///         // 从这里可以看到, 使用 map 来生成 publihser, 然后 switchToLatest 是一个套路.
    ///         .map() { index -> URLSession.DataTaskPublisher in
    ///             let url = URL(string: "https://example.org/get?index=\(index)")!
    ///             return URLSession.shared.dataTaskPublisher(for: url)
    ///         }
    ///         .switchToLatest()
    ///         .sink(receiveCompletion: { print("Complete: \($0)") },
    ///               receiveValue: { (data, response) in
    ///                 guard let url = response.url else {
    ///                     print("Bad response.")
    ///                     return
    ///                 }
    ///                 print("URL: \(url)")
    ///         })
    ///
    ///     for index in 1...5 {
    ///         DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index/10)) {
    ///             subject.send(index)
    ///         }
    ///     }
    ///
    ///     // Prints "URL: https://example.org/get?index=5"
    ///
    /// The exact behavior of this example depends on the value of `asyncAfter` and
    /// the speed of the network connection. If the delay value is longer, or the network
    /// connection is fast, the earlier data tasks may complete before `switchToLatest()`
    /// can cancel them. If this happens, the output includes multiple URLs whose tasks
    /// complete before cancellation.
    ///
    /*
     switchToLatest() 是一个操作符，它会重新发布由最近接收到的发布者发送的元素。

     该操作符适用于一个发布者的发布者，将元素的流扁平化，使其看起来就像它们来自单一的元素流。它会在接收到新的发布者时切换内部发布者，但对于下游订阅者来说，外部发布者保持不变。

     例如，给定类型 AnyPublisher<URLSession.DataTaskPublisher, NSError>，调用 switchToLatest() 的结果类型是 SwitchToLatest<(Data, URLResponse), URLError>。下游订阅者看到的是连续的 (Data, URLResponse) 元素，看起来像是来自单一的 URLSession.DataTaskPublisher，尽管这些元素来自不同的上游发布者。

     当此操作符从上游发布者接收到新的发布者时，它会取消先前的订阅。使用这个功能可以防止早期的发布者执行不必要的工作，比如从频繁更新的用户界面发布者创建网络请求发布者。

     下面的示例每隔 0.1 秒更新一个 PassthroughSubject 的新值。map(_:) 操作符接收新值，并使用它创建一个新的 URLSession.DataTaskPublisher。通过使用 switchToLatest() 操作符，下游sink订阅者接收来自数据任务发布者的 (Data, URLResponse) 输出类型，而不是由 map(_:) 操作符产生的 URLSession.DataTaskPublisher 类型。此外，创建每个新的数据任务发布者都会取消先前的数据任务发布者。

     swift
     Copy code
     let subject = PassthroughSubject<Int, Never>()
     cancellable = subject
         .setFailureType(to: URLError.self)
         .map { index -> URLSession.DataTaskPublisher in
             let url = URL(string: "https://example.org/get?index=\(index)")!
             return URLSession.shared.dataTaskPublisher(for: url)
         }
         .switchToLatest()
         .sink(
             receiveCompletion: { print("Complete: \($0)") },
             receiveValue: { (data, response) in
                 guard let url = response.url else {
                     print("Bad response.")
                     return
                 }
                 print("URL: \(url)")
             }
         )

     for index in 1...5 {
         DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(index/10)) {
             subject.send(index)
         }
     }

     // 打印 "URL: https://example.org/get?index=5"
     该示例的确切行为取决于 asyncAfter 的值和网络连接的速度。如果延迟值较长，或者网络连接速度很快，较早的数据任务可能在 switchToLatest() 能够取消它们之前完成。如果发生这种情况，输出将包含在取消之前完成的多个URL。
     */
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> {
        return .init(upstream: self)
    }
}

extension Publisher where Output: Publisher, Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<
        Output, Publishers.SetFailureType<Self, Output.Failure>
    > {
        return setFailureType(to: Output.Failure.self).switchToLatest()
    }
}

extension Publisher where Output: Publisher, Failure == Never, Output.Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<Output, Self> {
        return .init(upstream: self)
    }
}

extension Publisher where Output: Publisher, Output.Failure == Never {

    /// Republishes elements sent by the most recently received publisher.
    ///
    /// This operator works with an upstream publisher of publishers, flattening
    /// the stream of elements to appear as if they were coming from a single stream of
    /// elements. It switches the inner publisher as new ones arrive but keeps the outer
    /// publisher constant for downstream subscribers.
    ///
    /// When this operator receives a new publisher from the upstream publisher, it
    /// cancels its previous subscription. Use this feature to prevent earlier publishers
    /// from performing unnecessary work, such as creating network request publishers from
    /// frequently updating user interface publishers.
    public func switchToLatest() -> Publishers.SwitchToLatest<
        Publishers.SetFailureType<Output, Failure>,
        Publishers.Map<Self, Publishers.SetFailureType<Output, Failure>>
    > {
        return map { $0.setFailureType(to: Failure.self) }.switchToLatest()
    }
}

extension Publishers {

    /// A publisher that flattens nested publishers.
    ///
    /// Given a publisher that publishes `Publisher` instances,
    /// the `Publishers.SwitchToLatest` publisher produces a sequence of events from only
    /// the most recent one. For example, given the type
    /// `AnyPublisher<URLSession.DataTaskPublisher, NSError>`, calling `switchToLatest()`
    /// results in the type `SwitchToLatest<(Data, URLResponse), URLError>`.
    /// The downstream subscriber sees a continuous stream of `(Data, URLResponse)`
    /// elements from what looks like a single `URLSession.DataTaskPublisher` even though
    /// the elements are coming from different upstream publishers.
    ///
    /// When `Publishers.SwitchToLatest` receives a new publisher from the upstream
    /// publisher, it cancels its previous subscription. Use this feature to prevent
    /// earlier publishers from performing unnecessary work, such as creating network
    /// request publishers from frequently-updating user interface publishers.
    public struct SwitchToLatest<NestedPublisher: Publisher, Upstream: Publisher>
        : Publisher
        where Upstream.Output == NestedPublisher,
              Upstream.Failure == NestedPublisher.Failure
    {
        public typealias Output = NestedPublisher.Output

        public typealias Failure = NestedPublisher.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// Creates a publisher that “flattens” nested publishers.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let outer = Outer(downstream: subscriber)
            subscriber.receive(subscription: outer)
            // 这里有一个中转器, 它负责上游信息来临后的切换.
            upstream.subscribe(outer)
        }
    }
}

extension Publishers.SwitchToLatest {
    fileprivate final class Outer<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == NestedPublisher.Output,
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private var outerSubscription: Subscription?
        private var currentInnerSubscription: Subscription?
        private var currentInnerIndex: UInt64 = 0
        private var nextInnerIndex: UInt64 = 1
        private let lock = UnfairLock.allocate()
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private var cancelled = false
        private var finished = false
        private var sentCompletion = false
        private var awaitingInnerSubscription = false
        private var downstreamDemand = Subscribers.Demand.none

        init(downstream: Downstream) {
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard outerSubscription == nil && !cancelled else {
                lock.unlock()
                subscription.cancel()
                return
            }
            outerSubscription = subscription
            lock.unlock()
            subscription.request(.unlimited)
        }

        // 关键点.
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if cancelled || finished {
                lock.unlock()
                return .none
            }

            if let currentInnerSubscription = self.currentInnerSubscription.take()  {
                lock.unlock()
                // 在这里, 会把原来的进行取消.
                currentInnerSubscription.cancel()
                lock.lock()
            }

            let index = nextInnerIndex
            currentInnerIndex = index
            nextInnerIndex += 1
            awaitingInnerSubscription = true
            lock.unlock()
            // 然后这里, 新生成一个响应流.
            input.subscribe(Side(inner: self, index: index))
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            outerSubscription = nil
            finished = true

            if cancelled {
                lock.unlock()
                return
            }

            switch completion {
            case .finished:
                if awaitingInnerSubscription {
                    lock.unlock()
                    return
                }
                if currentInnerSubscription == nil {
                    sentCompletion = true
                    lock.unlock()
                    downstreamLock.lock()
                    downstream.receive(completion: completion)
                    downstreamLock.unlock()
                } else {
                    lock.unlock()
                }
            case .failure:
                let currentInnerSubscription = self.currentInnerSubscription.take()
                sentCompletion = true
                lock.unlock()
                currentInnerSubscription?.cancel()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            downstreamDemand += demand
            if let currentInnerSubscription = self.currentInnerSubscription {
                lock.unlock()
                currentInnerSubscription.request(demand)
            } else {
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            cancelled = true
            let currentInnerSubscription = self.currentInnerSubscription.take()
            let outerSubscription = self.outerSubscription.take()
            lock.unlock()

            currentInnerSubscription?.cancel()
            outerSubscription?.cancel()
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }

        private func receiveInner(subscription: Subscription, _ index: UInt64) {
            lock.lock()
            guard currentInnerIndex == index &&
                  !cancelled &&
                  currentInnerSubscription == nil else {
                lock.unlock()
                subscription.cancel()
                return
            }

            currentInnerSubscription = subscription
            awaitingInnerSubscription = false
            let downstreamDemand = self.downstreamDemand
            lock.unlock()
            if downstreamDemand > 0 {
                subscription.request(downstreamDemand)
            }
        }

        private func receiveInner(_ input: NestedPublisher.Output,
                                  _ index: UInt64) -> Subscribers.Demand {
            lock.lock()
            guard currentInnerIndex == index && !cancelled else {
                lock.unlock()
                return .none
            }

            // This will crash if we don't have any demand yet.
            // Combine crashes here too.
            downstreamDemand -= 1

            lock.unlock()
            downstreamLock.lock()
            // 下游接受到事件.
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand > 0 {
                lock.lock()
                downstreamDemand += newDemand
                lock.unlock()
            }

            return newDemand
        }

        private func receiveInner(completion: Subscribers.Completion<Failure>,
                                  _ index: UInt64) {
            lock.lock()
            guard currentInnerIndex == index && !cancelled else {
                lock.unlock()
                return
            }
            
            precondition(!awaitingInnerSubscription, "Unexpected completion")
            currentInnerSubscription = nil
            switch completion {
            case .finished:
                if sentCompletion || !finished {
                    lock.unlock()
                    return
                }
                sentCompletion = true
                lock.unlock()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            case .failure:
                if sentCompletion {
                    lock.unlock()
                    return
                }
                cancelled = true
                let outerSubscription = self.outerSubscription.take()
                sentCompletion = true
                lock.unlock()
                outerSubscription?.cancel()
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }
    }
}

extension Publishers.SwitchToLatest.Outer {
    private struct Side
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        typealias Input = NestedPublisher.Output

        typealias Failure = NestedPublisher.Failure

        typealias Outer =
            Publishers.SwitchToLatest<NestedPublisher, Upstream>.Outer<Downstream>

        private let index: UInt64
        private let outer: Outer

        let combineIdentifier = CombineIdentifier()

        init(inner: Outer, index: UInt64) {
            self.index = index
            self.outer = inner
        }

        func receive(subscription: Subscription) {
            outer.receiveInner(subscription: subscription, index)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return outer.receiveInner(input, index)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            outer.receiveInner(completion: completion, index)
        }

        var description: String { return "SwitchToLatest" }

        var customMirror: Mirror {
            let children = CollectionOfOne<Mirror.Child>(
                ("parentSubscription", outer.combineIdentifier)
            )
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
