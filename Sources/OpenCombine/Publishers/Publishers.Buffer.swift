
extension Publisher {
    
    /// Buffers elements received from an upstream publisher.
    ///
    /// Use `buffer(size:prefetch:whenFull:)` to collect a specific number of elements
    /// from an upstream publisher before republishing them to the downstream subscriber
    /// according to the `Publishers.BufferingStrategy` and `Publishers.PrefetchStrategy`
    /// strategy you specify.
    
    /// If the publisher completes before reaching the `size` threshold, it buffers
    /// the elements and publishes them downstream prior to completion.

    /// - Parameters:
    ///   - size: The maximum number of elements to store.
    ///   - prefetch: The strategy to initially populate the buffer.
    ///   - whenFull: The action to take when the buffer becomes full.
    /// - Returns: A publisher that buffers elements received from an upstream publisher.
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
        case keepFull // 提前获取
        
        /// A strategy that avoids prefetching and instead performs requests on demand.
        ///
        /// This strategy just forwards the downstream’s requests to the upstream
        /// publisher.
        case byRequest // 当下游节点 request 的才获取.
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
    // 惯例节点. 收集信息, 创建 Inner 对象
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
        
        private let downstream: Downstream
        
        private var state = SubscriptionStatus.awaitingSubscription
        
        private var downstreamDemand = Subscribers.Demand.none
        
        private var values = [Input]()
        
        private let prefetchSize: Int
        
        private let prefetchStrategy: Publishers.PrefetchStrategy // keepFull is 0x0
        
        private let whenFullStrategy: Publishers.BufferingStrategy<Failure>
        
        private var upstreamFailed = false
        
        private var terminal: Subscribers.Completion<Failure>?
        
        init(downstream: Downstream,
             size: Int,
             prefetch: Publishers.PrefetchStrategy,
             whenFull: Publishers.BufferingStrategy<Failure>) {
            self.prefetchSize = size
            self.prefetchStrategy = prefetch
            self.whenFullStrategy = whenFull
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
            // 状态管理, 强引用上级节点.
            state = .subscribed(subscription)
            lock.unlock()
            
            let upstreamDemand: Subscribers.Demand
            switch prefetchStrategy {
            case .keepFull:
                upstreamDemand = .max(prefetchSize)
            case .byRequest:
                // 这里是不是有问题. byRequest 不应该是 none 吗.
                upstreamDemand = .unlimited
            }
            // 根据 prefetchStrategy, 向上游进行了 Demand 的请求. 
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
            case nil, .finished?:
                // 如果, 还没有结束, 或者已经结束了.
                if values.count >= prefetchSize {
                    switch whenFullStrategy {
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
                    newDownstreamDemand += downstream.receive(value)
                    additionalUpstreamDemand += 1
                }
                
                if prefetchStrategy == .keepFull {
                    upstreamDemand += additionalUpstreamDemand
                }
                
                lock.lock()
                recursion = false
                downstreamDemand += newDownstreamDemand
            }
        }
        
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
