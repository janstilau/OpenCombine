extension Publisher {
    /// Transforms elements from the upstream publisher by providing the current
    /// element to a closure along with the last value returned by the closure.
    
    // 类似于 Reduce, 不过 reduce 是将每一个上游值操作之后, 在 finish 的时候统一发送给下游
    // scan, 则是每一个上游值到来后, 操作后, 发送给下游.
    
    /// Use `scan(_:_:)` to accumulate all previously-published values into a single
    /// value, which you then combine with each newly-published value.
    
    /// The following example logs a running total of all values received
    /// from the sequence publisher.
    ///
    ///     let range = (0...5)
    ///     cancellable = range.publisher
    ///         .scan(0) { return $0 + $1 }
    ///         .sink { print ("\($0)", terminator: " ") }
    ///      // Prints: "0 1 3 6 10 15 ".
    
    // 可以看到, initialResult, nextPartialResult 都没有增加 closure, callback 这样的名称后缀.
    // 真正的把 closure 当做值来进行处理.
    /// - Parameters:
    ///   - initialResult: The previous result returned by the `nextPartialResult`
    ///     closure.
    ///   - nextPartialResult: A closure that takes as its arguments the previous value
    ///     returned by the closure and the next element emitted from the upstream
    ///     publisher.
    /// - Returns: A publisher that transforms elements by applying a closure that
    ///   receives its previous return value and the next element from the upstream
    ///   publisher.
    public func scan<Result>(
        _ initialResult: Result,
        _ nextPartialResult: @escaping (Result, Output) -> Result
    ) -> Publishers.Scan<Self, Result> {
        return .init(upstream: self,
                     initialResult: initialResult,
                     nextPartialResult: nextPartialResult)
    }
    
    public func tryScan<Result>(
        _ initialResult: Result,
        _ nextPartialResult: @escaping (Result, Output) throws -> Result
    ) -> Publishers.TryScan<Self, Result> {
        return .init(upstream: self,
                     initialResult: initialResult,
                     nextPartialResult: nextPartialResult)
    }
}

extension Publishers {
    
    public struct Scan<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        public let upstream: Upstream
        
        public let initialResult: Output
        
        public let nextPartialResult: (Output, Upstream.Output) -> Output
        
        public init(upstream: Upstream,
                    initialResult: Output,
                    nextPartialResult: @escaping (Output, Upstream.Output) -> Output) {
            self.upstream = upstream
            self.initialResult = initialResult
            self.nextPartialResult = nextPartialResult
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Upstream.Failure == Downstream.Failure
        {
            upstream.subscribe(Inner(downstream: subscriber,
                                     initialResult: initialResult,
                                     nextPartialResult: nextPartialResult))
        }
    }
    
    public struct TryScan<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Error
        
        public let upstream: Upstream
        
        public let initialResult: Output
        
        // 可能会抛出异常的闭包, 使用 throws 进行修饰.
        public let nextPartialResult: (Output, Upstream.Output) throws -> Output
        
        public init(
            upstream: Upstream,
            initialResult: Output,
            nextPartialResult: @escaping (Output, Upstream.Output) throws -> Output
        ) {
            self.upstream = upstream
            self.initialResult = initialResult
            self.nextPartialResult = nextPartialResult
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Downstream.Failure == Error
        {
            upstream.subscribe(Inner(downstream: subscriber,
                                     initialResult: initialResult,
                                     nextPartialResult: nextPartialResult))
        }
    }
}

extension Publishers.Scan {
    
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Failure == Downstream.Failure
    {
        // 为什么这个不需要 Lock. 想不明白. 
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let nextPartialResult: (Downstream.Input, Input) -> Downstream.Input
        
        // 必然需要一个地方, 存储上次计算完成的结果.
        private var result: Downstream.Input
        
        fileprivate init(
            downstream: Downstream,
            initialResult: Downstream.Input,
            nextPartialResult: @escaping (Downstream.Input, Input) -> Downstream.Input
        )
        {
            self.result = initialResult
            self.downstream = downstream
            self.nextPartialResult = nextPartialResult
        }
        
        /*
         这个 Operator 不需要管理下游向上游的 Pull 行为, 所以直接将上游节点传递给下游. 
         */
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            // 每次, 更新 result 的值, 然后把 Result 的值, 交给下游节点.
            result = nextPartialResult(result, input)
            return downstream.receive(result)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
        
        
        var description: String { return "Scan" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("result", result)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryScan {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Failure == Error
    {
        // NOTE: this class has been audited for thread safety.
        
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let nextPartialResult:
        (Downstream.Input, Input) throws -> Downstream.Input
        
        private var result: Downstream.Input
        
        private var status = SubscriptionStatus.awaitingSubscription
        
        private let lock = UnfairLock.allocate()
        
        private var finished = false
        
        fileprivate init(
            downstream: Downstream,
            initialResult: Downstream.Input,
            nextPartialResult:
            @escaping (Downstream.Input, Input) throws -> Downstream.Input
        ) {
            self.downstream = downstream
            self.nextPartialResult = nextPartialResult
            self.result = initialResult
        }
        
        deinit {
            lock.deallocate()
        }
        
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            do {
                result = try nextPartialResult(result, input)
                return downstream.receive(result)
            } catch {
                // 如果, 在变化的过程中有错误, 直接就是 completion error 事件.
                lock.lock()
                guard case let .subscribed(subscription) = status else {
                    lock.unlock()
                    return .none
                }
                status = .terminal
                lock.unlock()
                subscription.cancel()
                // 如果出错了, 把 catch 到的错误, 传递到 downstream 中.
                downstream.receive(completion: .failure(error))
                return .none
            }
        }
        
        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            // Combine doesn't use locking in this method!
            guard case .subscribed = status else {
                return
            }
            downstream.receive(completion: completion.eraseError())
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            subscription.cancel()
        }
        
        
        
        
        var description: String { return "TryScan" }
        
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("status", status),
                ("result", result)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
