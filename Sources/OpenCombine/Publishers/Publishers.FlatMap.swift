extension Publisher {
    /// Transforms all elements from an upstream publisher into a new publisher up to
    /// a maximum number of publishers you specify.
    // 上游的每一个 Next 事件, 都是生成一个新的 Publisher. 下游节点, 其实是和这个新的 Publisher 的信号相连.
    
    /// OpenCombine‘s `flatMap(maxPublishers:_:)` operator performs a similar function
    /// to the `flatMap(_:)` operator in the Swift standard library, but turns
    /// the elements from one kind of publisher into a new publisher that is sent
    /// to subscribers.
    
    // 这是一个异步操作联合的操作符. 能够实现, Promise 串联的效果.
    /// Use `flatMap(maxPublishers:_:)` when you want to create a new
    /// series of events for downstream subscribers based on the received value.
    /// The closure creates the new `Publisher` based on the received value.
    
    // 是每一个原始的 Publihser 的数据, 都会生成一个新的 Publisher, 然后新的 Publihser 的数据, 是后方节点的数据.
    // 所有, 原始的 Publihser 的数据, 还是在正常的流转着.
    /// The new `Publisher` can emit more than one event, and successful completion of
    /// the new `Publisher` does not complete the overall stream.
    /// Failure of the new `Publisher` will fail the overall stream.
    
    
    /// In the example below, a `PassthroughSubject` publishes `WeatherStation` elements.
    /// The `flatMap(maxPublishers:_:)` receives each element, creates a `URL` from it,
    /// and produces a new `URLSession.DataTaskPublisher`, which will publish the data
    /// loaded from that `URL`.
    ///
    ///     public struct WeatherStation {
    ///         public let stationID: String
    ///     }
    ///
    ///     var weatherPublisher = PassthroughSubject<WeatherStation, URLError>()
    ///
    ///     cancellable = weatherPublisher
    ///         .flatMap {
    ///         接收到一个 WeatherStation 数据, 然后触发一个网络请求, 后续的节点, 是直接处理网络请求相关的数据信号.
    ///         station -> URLSession.DataTaskPublisher in
    ///             let url = URL(string: """
    ///             https://weatherapi.example.com/stations/\(station.stationID)\
    ///             /observations/latest
    ///             """)!
    ///             return URLSession.shared.dataTaskPublisher(for: url)
    ///         }
    ///         .sink(
    ///             receiveCompletion: { completion in
    ///                 // Handle publisher completion (normal or error).
    ///             },
    ///             receiveValue: {
    ///                 // Process the received data.
    ///             }
    ///          )
    ///
    ///     weatherPublisher.send(WeatherStation(stationID: "KSFO")) // San Francisco, CA
    ///     weatherPublisher.send(WeatherStation(stationID: "EGLC")) // London, UK
    ///     weatherPublisher.send(WeatherStation(stationID: "ZBBB")) // Beijing, CN
    
    /// - Parameters:
    ///   - maxPublishers: Specifies the maximum number of concurrent publisher
    ///     subscriptions, or `Subscribers.Demand.unlimited` if unspecified.
    
    ///   - transform: A closure that takes an element as a parameter and returns
    ///     a publisher that produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher into
    ///   a publisher of that element’s type.
    public func flatMap<Result, Child: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) -> Child
    ) -> Publishers.FlatMap<Child, Self>
    where Result == Child.Output, Failure == Child.Failure {
        return .init(upstream: self,
                     maxPublishers: maxPublishers,
                     transform: transform)
    }
}

extension Publisher where Failure == Never {
    
    /// Transforms all elements from an upstream publisher into a new publisher up to
    /// a maximum number of publishers you specify.
    ///
    /// - Parameters:
    ///   - maxPublishers: Specifies the maximum number of concurrent publisher
    ///     subscriptions, or `Subscribers.Demand.unlimited` if unspecified.
    ///   - transform: A closure that takes an element as a parameter and returns
    ///     a publisher that produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher into
    ///   a publisher of that element’s type.
    
    public func flatMap<Child: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) -> Child
    ) -> Publishers.FlatMap<Child, Publishers.SetFailureType<Self, Child.Failure>> {
        return setFailureType(to: Child.Failure.self)
            .flatMap(maxPublishers: maxPublishers, transform)
    }
    
    /// Transforms all elements from an upstream publisher into a new publisher up to
    /// a maximum number of publishers you specify.
    ///
    /// - Parameters:
    ///   - maxPublishers: Specifies the maximum number of concurrent publisher
    ///     subscriptions, or `Subscribers.Demand.unlimited` if unspecified.
    ///   - transform: A closure that takes an element as a parameter and returns
    ///     a publisher that produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher
    ///   into a publisher of that element’s type.
    public func flatMap<Child: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) -> Child
    ) -> Publishers.FlatMap<Child, Self> where Child.Failure == Never {
        return .init(upstream: self, maxPublishers: maxPublishers, transform: transform)
    }
}

extension Publisher {
    
    /// Transforms all elements from an upstream publisher into a new publisher up to
    /// a maximum number of publishers you specify.
    ///
    /// - Parameters:
    ///   - maxPublishers: Specifies the maximum number of concurrent publisher
    ///     subscriptions, or `Subscribers.Demand.unlimited` if unspecified.
    ///   - transform: A closure that takes an element as a parameter and returns
    ///     a publisher that produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher into
    ///   a publisher of that element’s type.
    public func flatMap<Child: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) -> Child
    ) -> Publishers.FlatMap<Publishers.SetFailureType<Child, Failure>, Self>
    where Child.Failure == Never
    {
        return flatMap(maxPublishers: maxPublishers) {
            transform($0).setFailureType(to: Failure.self)
        }
    }
}

extension Publishers {
    
    /// A publisher that transforms elements from an upstream publisher into a new
    /// publisher.
    public struct FlatMap<ChildPublisher: Publisher,
                          Upstream: Publisher>: Publisher
    where ChildPublisher.Failure == Upstream.Failure
    {
        public typealias Output = ChildPublisher.Output
        
        public typealias Failure = Upstream.Failure
        
        public let upstream: Upstream
        
        public let maxPublishers: Subscribers.Demand
        
        public let childPublisherCreator: (Upstream.Output) -> ChildPublisher
        
        public init(upstream: Upstream, maxPublishers: Subscribers.Demand,
                    transform: @escaping (Upstream.Output) -> ChildPublisher) {
            self.upstream = upstream
            self.maxPublishers = maxPublishers
            self.childPublisherCreator = transform
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where ChildPublisher.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            let outer = OuterSink(downstream: subscriber,
                                  maxPublishers: maxPublishers,
                                  map: childPublisherCreator)
            subscriber.receive(subscription: outer)
            upstream.subscribe(outer)
        }
    }
}

extension Publishers.FlatMap {
    private final class OuterSink<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == ChildPublisher.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private typealias SubscriptionIndex = Int
        
        /// All requests to this subscription should be made with the `outerLock`
        /// acquired.
        private var outerSubscription: Subscription?
        
        /// The lock for requesting from `outerSubscription`.
        private let outerLock = UnfairRecursiveLock.allocate()
        
        /// The lock for modifying the state. All mutable state here should be
        /// read and modified with this lock acquired.
        /// The only exception is the `downstreamRecursive` field, which is guarded
        /// by the `downstreamLock`.
        private let internalLock = UnfairLock.allocate()
        
        /// All the calls to the downstream subscriber should be made with this lock
        /// acquired.
        private let downstreamLock = UnfairRecursiveLock.allocate()
        
        private let downstream: Downstream
        
        private var downstreamDemand = Subscribers.Demand.none
        
        /// This variable is set to `true` whenever we call `downstream.receive(_:)`,
        /// and then set back to `false`.
        private var downstreamRecursive = false
        
        private var innerRecursive = false
        
        private var nextInnerIndex: SubscriptionIndex = 0
        private var childSubscriptionCount = 0
        // 中间节点的管理器.
        private var childSubscription = [SubscriptionIndex : Subscription]()
        // 中间节点产生的数据的管理器.
        private var buffer = [(SubscriptionIndex, ChildPublisher.Output)]()
        private let maxPublishers: Subscribers.Demand
        private let childPublisherCreator: (Input) -> ChildPublisher
        private var cancelledOrCompleted = false
        private var outerFinished = false
        
        init(downstream: Downstream,
             maxPublishers: Subscribers.Demand,
             map: @escaping (Upstream.Output) -> ChildPublisher) {
            self.downstream = downstream
            self.maxPublishers = maxPublishers
            self.childPublisherCreator = map
        }
        
        deinit {
            outerLock.deallocate()
            internalLock.deallocate()
            downstreamLock.deallocate()
        }
        
        // MARK: - Subscriber
        
        // 接收到了, 原始 UpStream 生成的节点数据.
        fileprivate func receive(subscription: Subscription) {
            internalLock.lock()
            guard outerSubscription == nil, !cancelledOrCompleted else {
                internalLock.unlock()
                subscription.cancel()
                return
            }
            // 存储原始的 Upstream 生成的 Subscription 节点.
            outerSubscription = subscription
            internalLock.unlock()
            
            // 这个时候, 没有像普通的 Opertor 那样, 将自身传递给了下游.
            // maxPublishers 的作用在这体现了, 本 Subscription 只会要这么多, 在 receive 之后, 不会要更多的 demand
            subscription.request(maxPublishers)
        }
        
        fileprivate func receive(_ input: Input) -> Subscribers.Demand {
            internalLock.lock()
            let cancelledOrCompleted = self.cancelledOrCompleted
            internalLock.unlock()
            if cancelledOrCompleted {
                return .none
            }
            // 在这里, 产生了 新的 Publisher.
            let child = childPublisherCreator(input)
            
            internalLock.lock()
            let innerIndex = nextInnerIndex
            nextInnerIndex += 1
            childSubscriptionCount += 1
            internalLock.unlock()
            // 新的 Publisher是将和 Side 对象进行了 attach.
            child.subscribe(Side(index: innerIndex, inner: self))
            return .none
        }
        
        fileprivate func receive(completion: Subscribers.Completion<Failure>) {
            internalLock.lock()
            outerSubscription = nil
            outerFinished = true
            switch completion {
            case .finished:
                releaseLockThenSendCompletionDownstreamIfNeeded(outerFinished: true)
                return
            case .failure:
                let wasAlreadyCancelledOrCompleted = cancelledOrCompleted
                cancelledOrCompleted = true
                // 如果发生了错误, 那么后续节点, 接收到错误时间. 并且, 把之前所有的中间节点释放.
                for (_, subscription) in childSubscription {
                    // Cancelling subscriptions with the lock acquired. Not good,
                    // but that's what Combine does. This code path is tested.
                    subscription.cancel()
                }
                childSubscription = [:]
                internalLock.unlock()
                if wasAlreadyCancelledOrCompleted {
                    return
                }
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }
        
        // MARK: - Subscription
        
        fileprivate func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            if downstreamRecursive {
                // downstreamRecursive being true means that downstreamLock
                // is already acquired.
                downstreamDemand += demand
                return
            }
            internalLock.lock()
            if cancelledOrCompleted {
                internalLock.unlock()
                return
            }
            if demand == .unlimited {
                downstreamDemand = .unlimited
                let buffer = self.buffer.take()
                let subscriptions = self.childSubscription
                internalLock.unlock()
                
                downstreamLock.lock()
                downstreamRecursive = true
                for (_, childOutput) in buffer {
                    _ = downstream.receive(childOutput)
                }
                downstreamRecursive = false
                downstreamLock.unlock()
                
                // 下游的 demand, 不是给 Upstream 的, 而是由 FlatMap 生成的 Publisher.
                for (_, subscription) in subscriptions {
                    subscription.request(.unlimited)
                }
                internalLock.lock()
            } else {
                downstreamDemand += demand
                // 当下游有 Demand 需求的时候, 是找已经注册的 FlatMap Publisher 生成的 Subscription, 找他们要值.
                while !buffer.isEmpty && downstreamDemand > 0 {
                    let (index, value) = buffer.removeFirst()
                    downstreamDemand -= 1
                    let subscription = childSubscription[index]
                    internalLock.unlock()
                    
                    downstreamLock.lock()
                    downstreamRecursive = true
                    let additionalDemand = downstream.receive(value)
                    downstreamRecursive = false
                    downstreamLock.unlock()
                    
                    if additionalDemand != .none {
                        internalLock.lock()
                        downstreamDemand += additionalDemand
                        internalLock.unlock()
                    }
                    
                    if let subscription = subscription {
                        innerRecursive = true
                        subscription.request(.max(1))
                        innerRecursive = false
                    }
                    internalLock.lock()
                }
            }
            releaseLockThenSendCompletionDownstreamIfNeeded(outerFinished: outerFinished)
        }
        
        fileprivate func cancel() {
            internalLock.lock()
            if cancelledOrCompleted {
                internalLock.unlock()
                return
            }
            cancelledOrCompleted = true
            let subscriptions = self.childSubscription.take()
            let outerSubscription = self.outerSubscription.take()
            internalLock.unlock()
            for (_, subscription) in subscriptions {
                subscription.cancel()
            }
            // Combine doesn't acquire outerLock here. Weird.
            outerSubscription?.cancel()
        }
        
        // MARK: - Reflection
        
        fileprivate var description: String { return "FlatMap" }
        
        fileprivate var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        fileprivate var playgroundDescription: Any { return description }
        
        
        // MARK: - Private
        private func receiveInner(subscription: Subscription,
                                  _ index: SubscriptionIndex) {
            internalLock.lock()
            childSubscriptionCount -= 1
            childSubscription[index] = subscription
            
            let demand = downstreamDemand == .unlimited
            ? Subscribers.Demand.unlimited
            : .max(1)
            
            internalLock.unlock()
            subscription.request(demand)
        }
        
        // 创建的 ChildPublisher 发送数据过来了.
        // 注意, 所有的 ChildPublisher 其实是公用了一个 downstream 的.
        // 所以该加锁必须加锁.
        private func receiveInner(_ input: ChildPublisher.Output,
                                  _ index: SubscriptionIndex) -> Subscribers.Demand {
            internalLock.lock()
            if downstreamDemand == .unlimited {
                internalLock.unlock()
                
                downstreamLock.lock()
                downstreamRecursive = true
                _ = downstream.receive(input)
                downstreamRecursive = false
                downstreamLock.unlock()
                
                return .none
            }
            // 如果当前下游没有 Demand 需求, 需要进行缓存.
            if downstreamDemand == .none || innerRecursive {
                buffer.append((index, input))
                internalLock.unlock()
                return .none
            }
            downstreamDemand -= 1
            internalLock.unlock()
            
            downstreamLock.lock()
            downstreamRecursive = true
            // 直到这个时候, 后续节点才真正的拿到了数据.
            let newDemand = downstream.receive(input)
            downstreamRecursive = false
            downstreamLock.unlock()
            
            if newDemand > 0 {
                internalLock.lock()
                downstreamDemand += newDemand
                internalLock.unlock()
            }
            return .max(1)
        }
        
        private func receiveInner(completion: Subscribers.Completion<ChildPublisher.Failure>,
                                  _ index: SubscriptionIndex) {
            switch completion {
            case .finished:
                internalLock.lock()
                childSubscription.removeValue(forKey: index)
                let downstreamCompleted = releaseLockThenSendCompletionDownstreamIfNeeded(
                    outerFinished: outerFinished
                )
                // 当 ChildPublisher 结束了, 才会想上游要另外的一个 Demand.
                if !downstreamCompleted {
                    requestOneMorePublisher()
                }
                // Child 失败了一次, 就算作整个 chain 都失败了.
            case .failure:
                internalLock.lock()
                if cancelledOrCompleted {
                    internalLock.unlock()
                    return
                }
                cancelledOrCompleted = true
                let subscriptions = self.childSubscription.take()
                internalLock.unlock()
                for (i, subscription) in subscriptions where i != index {
                    subscription.cancel()
                }
                downstreamLock.lock()
                downstream.receive(completion: completion)
                downstreamLock.unlock()
            }
        }
        
        private func requestOneMorePublisher() {
            if maxPublishers != .unlimited {
                outerLock.lock()
                outerSubscription?.request(.max(1))
                outerLock.unlock()
            }
        }
        
        /// - Precondition: `lock` is acquired
        /// - Postcondition: `lock` is released
        ///
        /// - Returns: `true` if a completion was sent downstream
        @discardableResult
        private func releaseLockThenSendCompletionDownstreamIfNeeded(
            outerFinished: Bool
        ) -> Bool {
            // 必须等到 FlatMap 生成的 Publsiher 也完毕了.
            if !cancelledOrCompleted && outerFinished && buffer.isEmpty &&
                childSubscription.count + childSubscriptionCount == 0 {
                cancelledOrCompleted = true
                internalLock.unlock()
                downstreamLock.lock()
                downstream.receive(completion: .finished)
                downstreamLock.unlock()
                return true
            }
            
            internalLock.unlock()
            return false
        }
        
        // MARK: - Side
        
        // 新生成的 Publisher, 面对的下游是这个 Side.
        private struct Side: Subscriber,
                             CustomStringConvertible,
                             CustomReflectable,
                             CustomPlaygroundDisplayConvertible {
            private let index: SubscriptionIndex
            private let inner: OuterSink
            fileprivate let combineIdentifier = CombineIdentifier()
            
            fileprivate init(index: SubscriptionIndex, inner: OuterSink) {
                self.index = index
                self.inner = inner
            }
            
            // 所有的, Subscriber 的实现, 都是调用的相对应的方法.
            fileprivate func receive(subscription: Subscription) {
                inner.receiveInner(subscription: subscription, index)
            }
            
            fileprivate func receive(_ input: ChildPublisher.Output) -> Subscribers.Demand {
                return inner.receiveInner(input, index)
            }
            
            fileprivate func receive(completion: Subscribers.Completion<ChildPublisher.Failure>) {
                inner.receiveInner(completion: completion, index)
            }
            
            
            
            
            fileprivate var description: String { return "FlatMap" }
            
            fileprivate var customMirror: Mirror {
                let children = CollectionOfOne<Mirror.Child>(
                    ("parentSubscription", inner.combineIdentifier)
                )
                return Mirror(self, children: children)
            }
            
            fileprivate var playgroundDescription: Any { return description }
        }
    }
}
