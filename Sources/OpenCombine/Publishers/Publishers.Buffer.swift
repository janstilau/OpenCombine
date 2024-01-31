
extension Publisher {
    
    /// Buffers elements received from an upstream publisher.
    ///
    /// Use `buffer(size:prefetch:whenFull:)` to collect a specific number of elements
    /// from an upstream publisher before republishing them to the downstream subscriber
    /// according to the `Publishers.BufferingStrategy` and `Publishers.PrefetchStrategy`
    /// strategy you specify.
    ///
    /// If the publisher completes before reaching the `size` threshold, it buffers
    /// the elements and publishes them downstream prior to completion.
    ///
    /// - Parameters:
    ///   - size: The maximum number of elements to store.
    ///   - prefetch: The strategy to initially populate the buffer.
    ///   - whenFull: The action to take when the buffer becomes full.
    /// - Returns: A publisher that buffers elements received from an upstream publisher.
    /// 缓冲来自上游发布者的元素。
    ///
    /// 使用 `buffer(size:prefetch:whenFull:)` 来在按照指定的 `Publishers.BufferingStrategy` 和 `Publishers.PrefetchStrategy` 策略之前，从上游发布者收集特定数量的元素，并将它们重新发布给下游订阅者。
    ///
    /// 如果发布者在达到 `size` 阈值之前完成，它会在完成之前缓冲元素并将它们发布到下游。
    ///
    /// - Parameters:
    ///   - size: 要存储的元素的最大数量。
    ///   - prefetch: 初始填充缓冲区的策略。
    ///   - whenFull: 当缓冲区变满时要采取的操作。
    /// - Returns: 一个发布者，用于缓冲来自上游发布者的元素。
    
    // 不是每一份数据, 都发送给下游. 而是积累了一部分之后才开始.
    public func buffer(
        size: Int,
        prefetch: Publishers.PrefetchStrategy,
        whenFull: Publishers.BufferingStrategy<Failure>
    ) -> Publishers.Buffer<Self> {
        return .init(upstream: self,
                     size: size,
                     prefetch: prefetch,
                     whenFull: whenFull)
    }
}

extension Publishers {
    
    /// A strategy for filling a buffer.
    public enum PrefetchStrategy {
        
        /// A strategy to fill the buffer at subscription time, and keep it full
        /// thereafter.
        ///
        /// This strategy starts by making a demand equal to the buffer’s size from
        /// the upstream when the subscriber first connects. Afterwards, it continues
        /// to demand elements from the upstream to try to keep the buffer full.
        
        /// 一种在订阅时填充缓冲区并在此后保持缓冲区充满的策略。
        ///
        /// 此策略在订阅时首次连接时，从上游进行一次需求，需求量等于缓冲区的大小。之后，它继续向上游发出元素的需求，以尝试保持缓冲区的充满状态。
        case keepFull
        
        /// A strategy that avoids prefetching and instead performs requests on demand.
        ///
        /// This strategy just forwards the downstream’s requests to the upstream
        /// publisher.
        case byRequest
    }
    
    /// A strategy that handles exhaustion of a buffer’s capacity.
    public enum BufferingStrategy<Failure: Error> {
        
        /// When the buffer is full, discard the newly received element.
        case dropNewest
        
        /// When the buffer is full, discard the oldest element in the buffer.
        case dropOldest
        
        /// When the buffer is full, execute the closure to provide a custom error.
        case customError(() -> Failure)
    }
    
    /// A publisher that buffers elements received from an upstream publisher.
    public struct Buffer<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The maximum number of elements to store.
        public let size: Int
        
        /// The strategy for initially populating the buffer.
        public let prefetch: Publishers.PrefetchStrategy
        
        /// The action to take when the buffer becomes full.
        public let whenFull: Publishers.BufferingStrategy<Failure>
        
        /// Creates a publisher that buffers elements received from an upstream publisher.
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        /// - Parameter size: The maximum number of elements to store.
        /// - Parameter prefetch: The strategy for initially populating the buffer.
        /// - Parameter whenFull: The action to take when the buffer becomes full.
        public init(upstream: Upstream,
                    size: Int,
                    prefetch: Publishers.PrefetchStrategy,
                    whenFull: Publishers.BufferingStrategy<Failure>) {
            self.upstream = upstream
            self.size = size
            self.prefetch = prefetch
            self.whenFull = whenFull
        }
        
        // 惯例的实现, 在下游真正来临时候, 真正生成 Sink 节点, Sink 节点连接下游节点, 然后将 Sink 节点交给上游, 重复构建的过程.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber,
                              size: size,
                              prefetch: prefetch,
                              whenFull: whenFull)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.PrefetchStrategy: Equatable {}

extension Publishers.PrefetchStrategy: Hashable {}

extension Publishers.Buffer {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let lock = UnfairLock.allocate()
        
        private var recursion = false
        
        private let size: Int
        
        private let prefetch: Publishers.PrefetchStrategy // keepFull is 0x0
        
        private let whenFull: Publishers.BufferingStrategy<Failure>
        
        private let downstream: Downstream
        
        private var state = SubscriptionStatus.awaitingSubscription
        
        private var downstreamDemand = Subscribers.Demand.none
        
        // TODO: Use a deque here?
        // Need to measure performance with large buffers and `dropOldest` strategy.
        private var values = [Input]()
        
        private var upstreamFailed = false
        
        private var terminal: Subscribers.Completion<Failure>?
        
        init(downstream: Downstream,
             size: Int,
             prefetch: Publishers.PrefetchStrategy,
             whenFull: Publishers.BufferingStrategy<Failure>) {
            self.size = size
            self.prefetch = prefetch
            self.whenFull = whenFull
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
        }
        
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            lock.unlock()
            
            // prefetch 控制的是, 如何拉取上游的数据.
            // 在创建连接的时候, 以及一次性发送数据给下游后, 会使用该值, 重现拉取上游的数据.
            let upstreamDemand: Subscribers.Demand
            switch prefetch {
            case .keepFull:
                upstreamDemand = .max(size)
            case .byRequest:
                upstreamDemand = .unlimited
            }
            subscription.request(upstreamDemand)
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return .none
            }
            switch terminal {
            case nil, .finished?: // 原来还能这么匹配.
                if values.count >= size {
                    switch whenFull {
                    case .dropNewest:
                        lock.unlock()
                        return drain()
                    case .dropOldest:
                        values.removeFirst()
                    case let .customError(makeError):
                        terminal = .failure(makeError())
                        lock.unlock()
                        subscription.cancel()
                        return .none
                    }
                }
                
                values.append(input)
                lock.unlock()
                return drain()
            case .failure?:
                lock.unlock()
                return .none
            }
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case .subscribed = state, terminal == nil else {
                lock.unlock()
                return
            }
            terminal = completion
            lock.unlock()
            // 最后其实吧剩余的数据发送过来. 
            _ = drain()
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            let recursion = self.recursion
            lock.unlock()
            // 下游
            if recursion {
                return
            }
            
            let more = drain()
            if more != .none {
                // Request the number of items just enough to fill the buffer.
                subscription.request(more)
            }
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            values = []
            lock.unlock()
            subscription.cancel()
        }
        
        private func drain() -> Subscribers.Demand {
            var upstreamDemand = Subscribers.Demand.none
            lock.lock()
            while true {
                guard case .subscribed = state else {
                    lock.unlock()
                    return upstreamDemand
                }
                
                if downstreamDemand > 0 {
                    // 下游有需求, 但是上游没值
                    if values.isEmpty {
                        if let completion = terminal {
                            state = .terminal
                            lock.unlock()
                            downstream.receive(completion: completion)
                        } else {
                            lock.unlock()
                        }
                        return upstreamDemand
                    }
                } else {
                    if let completion = terminal, case .failure = completion {
                        state = .terminal
                        lock.unlock()
                        downstream.receive(completion: completion)
                    } else {
                        lock.unlock()
                    }
                    return upstreamDemand
                }
                
                let poppedValues = lockedPop(downstreamDemand)
                assert(poppedValues.count > 0,
                       """
                       We check that the buffer is not empty and downstreamDemand is \
                       nonzero, how can this be triggered?
                       """)
                
                // This should not crash because `lockedPop(_:)` returns at most
                // `downstreamDemand` items.
                downstreamDemand -= poppedValues.count
                
                recursion = true
                lock.unlock()
                
                var newDownstreamDemand = Subscribers.Demand.none
                var additionalUpstreamDemand = 0
                
                for value in poppedValues {
                    // 发送数据.
                    newDownstreamDemand += downstream.receive(value)
                    additionalUpstreamDemand += 1
                }
                
                if prefetch == .keepFull {
                    upstreamDemand += additionalUpstreamDemand
                }
                
                lock.lock()
                recursion = false
                downstreamDemand += newDownstreamDemand
            }
        }
        
        // 取出要发送的数据.
        private func lockedPop(_ demand: Subscribers.Demand) -> [Input] {
            assert(demand > 0)
            guard let max = demand.max else {
                return values.take()
            }
            
            let poppedValues = Array(values.prefix(max))
            values.removeFirst(poppedValues.count)
            return poppedValues
        }
        
        var description: String { return "Buffer" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("values", values),
                ("state", state),
                ("downstreamDemand", downstreamDemand),
                ("terminal", terminal as Any)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
