extension Publisher {
    
    /// Replaces any errors in the stream with the provided element.
    
    /// If the upstream publisher fails with an error, this publisher emits the provided
    /// element, then finishes normally.
    // 使用, 提供的元素, 当错误发生的时候, 进行替换.
    
    /// In the example below, a publisher of strings fails with a `MyError` instance,
    /// which sends a failure completion downstream. The `replaceError(with:)` operator
    /// handles the failure by publishing the string `(replacement element)` and
    /// completing normally.
    
    ///
    ///     struct MyError: Error {}
    ///     let fail = Fail<String, MyError>(error: MyError())
    ///     cancellable = fail
    ///         .replaceError(with: "(replacement element)")
    ///         .sink(
    ///             receiveCompletion: { print ("\($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///         )
    ///
    ///     // Prints: "(replacement element) finished".
    ///
    
    /// This `replaceError(with:)` functionality is useful when you want to handle
    /// an error by sending a single replacement element and end the stream.
    /// Use `catch(_:)` to recover from an error and provide a replacement publisher
    /// to continue providing elements to the downstream subscriber.
    
    /// - Parameter output: An element to emit when the upstream publisher fails.
    /// - Returns: A publisher that replaces an error from the upstream publisher with
    ///   the provided output element.
    public func replaceError(with output: Output) -> Publishers.ReplaceError<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publishers {
    /// A publisher that replaces any errors in the stream with a provided element.
    public struct ReplaceError<Upstream: Publisher>: Publisher {
        
        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output
        
        /// The kind of errors this publisher might publish.
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Never
        
        /// The element with which to replace errors from the upstream publisher.
        public let output: Upstream.Output
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        public init(upstream: Upstream,
                    output: Output) {
            self.upstream = upstream
            self.output = output
        }
        
        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Output == Downstream.Input, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, output: output))
        }
    }
}

extension Publishers.ReplaceError: Equatable
where Upstream: Equatable, Upstream.Output: Equatable {}

extension Publishers.ReplaceError {
    
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let output: Upstream.Output
        private let downstream: Downstream
        private var status = SubscriptionStatus.awaitingSubscription
        private var terminated = false
        // 因为 replace error 是发送了错误之后, 多余发送了一个值到下游.
        // 所以在本 Subscription 中, 管理了 demand, 当 error 到达之后, 只有下游真的需要, 才进行多余的 replace value 的发送.
        private var pendingDemand = Subscribers.Demand.none
        private var lock = UnfairLock.allocate()
        
        fileprivate init(downstream: Downstream, output: Upstream.Output) {
            self.downstream = downstream
            self.output = output
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 惯例实现.
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
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return .none
            }
            pendingDemand -= 1
            lock.unlock()
            let demand = downstream.receive(input)
            if demand == .none {
                return .none
            }
            lock.lock()
            pendingDemand += demand
            lock.unlock()
            // 还是给上游传递下游发送过来的 demand.
            // 本类重写该方法, 只是为了进行 pendingDemand 的管理.
            return demand
        }
        
        // 作为下游节点, 其实是需要进行状态的 Check 的. 因为上游可能连续发送两个 completion 事件过来.
        // 它保留着下游的引用, 就可以一直发. 这是上游节点的设计问题. 在自己的类内部, 一定要保证自身的逻辑完备性.
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = status, !terminated else {
                lock.unlock()
                return
            }
            switch completion {
            case .finished:
                // 惯例实现.
                status = .terminal
                lock.unlock()
                downstream.receive(completion: .finished)
            case .failure:
                // If there was no demand from downstream,
                // ReplaceError does not forward the value that
                // replaces the error until it is requested.
                /*
                 pendingDemand 在这里使用了.
                 这个值存在的意义就是自己记录下游的 demand, 当失败的时候, 其实需要多发送一个 Value 给下游, 但是如果下游不需要呢.
                 如果下游不需要, 那么就是在下游 request demand 的时候, 在进行这个发送的操作.
                 */
                if pendingDemand == .none {
                    terminated = true
                    lock.unlock()
                    return
                }
                status = .terminal
                lock.unlock()
                // 发生了错误, 输出 replace 的值, 然后结束.
                // ReplaceError 并不是忽略错误, 最终还是导致了完成.
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if terminated {
                status = .terminal
                lock.unlock()
                // 已经发生了错误, 发送 replace 的值, 然后结束.
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
                return
            }
            // 所以, 这里之所以有 Demand 的管理, 是因为处理, 当发生错误的时候, 是否应该发送 ReplacedElement 到后方节点.
            pendingDemand += demand
            // 下面这是惯例的实现
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }
        
        // 这里是惯例实现. 
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
        
        
        
        var description: String { return "ReplaceError" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}
