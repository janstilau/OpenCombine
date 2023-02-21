
extension Publisher {
    /// Republishes elements until another publisher emits an element.
    
    /// After the second publisher publishes an element, the publisher returned by this
    /// method finishes.
    
    /// - Parameter publisher: A second publisher.
    /// - Returns: A publisher that republishes elements until the second publisher
    ///   publishes an element.
    public func prefix<Other: Publisher>(
        untilOutputFrom publisher: Other
    ) -> Publishers.PrefixUntilOutput<Self, Other> {
        return .init(upstream: self, other: publisher)
    }
}

extension Publishers {
    public struct PrefixUntilOutput<Upstream: Publisher, Other: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// Another publisher, whose first output causes this publisher to finish.
        public let other: Other
        
        public init(upstream: Upstream, other: Other) {
            self.upstream = upstream
            self.other = other
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber, trigger: other))
        }
    }
}

extension Publishers.PrefixUntilOutput {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private struct Termination: Subscriber {
            
            let inner: Inner
            
            var combineIdentifier: CombineIdentifier {
                return inner.combineIdentifier
            }
            
            // 非常好的命名方式
            // 没有做任何的处理, 都是交给了 PrefixUntilOutput 处理.
            // 因为所有的数据和逻辑, 其实都在 PrefixUntilOutput 的内部.
            func receive(subscription: Subscription) {
                inner.terminationReceive(subscription: subscription)
            }
            
            func receive(_ input: Other.Output) -> Subscribers.Demand {
                return inner.terminationReceive(input)
            }
            
            func receive(completion: Subscribers.Completion<Other.Failure>) {
                inner.terminationReceive(completion: completion)
            }
        }
        
        private var termination: Termination?
        private var chainState = SubscriptionStatus.awaitingSubscription
        private var terminationState = SubscriptionStatus.awaitingSubscription
        private var triggered = false
        private let lock = UnfairLock.allocate()
        private let downstream: Downstream
        
        init(downstream: Downstream, trigger: Other) {
            self.downstream = downstream
            
            // 在一开始, 就进行了 Termination 相关的 attach
            // 所以, 有可能 Termination 的信号先触发的.
            let termination = Termination(inner: self)
            self.termination = termination
            trigger.subscribe(termination)
        }
        
        deinit {
            lock.deallocate()
        }
        
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = chainState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 有可能, Ternimate 先触发了. 所以这里要判断 triggered 的状态的.
            chainState = triggered ? .terminal : .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }
        
        // 只要收到上游数据, 就下发
        // 当 terminate 了, 会直接取消上游的.
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = chainState else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            let prefixState = self.chainState
            let terminationSubscription = terminationState.subscription
            self.chainState = .terminal
            terminationState = .terminal
            termination = nil
            lock.unlock()
            
            terminationSubscription?.cancel()
            if case .subscribed = prefixState {
                downstream.receive(completion: completion)
            }
        }
        
        // 惯例实现.
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = chainState else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }
        
        // 两个响应链, 都进行 cancel.
        func cancel() {
            lock.lock()
            let prefixSubscription = chainState.subscription
            let terminationSubscription = terminationState.subscription
            chainState = .terminal
            terminationState = .terminal
            lock.unlock()
            prefixSubscription?.cancel()
            terminationSubscription?.cancel()
        }
        
        
        
        
        // MARK: - Private
        
        private func terminationReceive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = terminationState else {
                lock.unlock()
                subscription.cancel()
                return
            }
            terminationState = .subscribed(subscription)
            lock.unlock()
            // 只要一个.
            subscription.request(.max(1))
        }
        
        private func terminationReceive(_ input: Other.Output) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = terminationState else {
                lock.unlock()
                return .none
            }
            let prefixSubscription = chainState.subscription
            chainState = .terminal
            terminationState = .terminal
            termination = nil
            triggered = true
            lock.unlock()
            // 当另外一个发送数据后, 完成原本的 chain 的销毁.
            prefixSubscription?.cancel()
            downstream.receive(completion: .finished)
            return .none
        }
        
        // 永远不会销毁了. 
        private func terminationReceive(
            completion: Subscribers.Completion<Other.Failure>
        ) {
            lock.lock()
            terminationState = .terminal
            termination = nil
            lock.unlock()
        }
    }
}
