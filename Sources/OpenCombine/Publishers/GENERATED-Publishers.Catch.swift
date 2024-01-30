extension Publisher {

    /// Handles errors from an upstream publisher by replacing it with another publisher.
    ///
    /// Use `catch()` to replace an error from an upstream publisher with a new publisher.
    ///
    /// In the example below, the `catch()` operator handles the `SimpleError` thrown by
    /// the upstream publisher by replacing the error with a `Just` publisher. This
    /// continues the stream by publishing a single value and completing normally.
    ///
    ///     struct SimpleError: Error {}
    ///     let numbers = [5, 4, 3, 2, 1, 0, 9, 8, 7, 6]
    ///     cancellable = numbers.publisher
    ///         .tryLast(where: {
    ///             guard $0 != 0 else { throw SimpleError() }
    ///             return true
    ///         })
    ///         .catch { error in
    ///             Just(-1)
    ///         }
    ///         .sink { print("\($0)") }
    ///         // Prints: -1
    ///
    /// Backpressure note: This publisher passes through `request` and `cancel` to
    /// the upstream. After receiving an error, the publisher sends sends any unfulfilled
    /// demand to the new `Publisher`.
    ///
    /// - SeeAlso: `replaceError`
    /// - Parameter handler: A closure that accepts the upstream failure as input and
    ///   returns a publisher to replace the upstream publisher.
    /// - Returns: A publisher that handles errors from an upstream publisher by replacing
    ///   the failed publisher with another publisher.
    
    /// 通过使用另一个发布者替换上游发布者来处理上游发布者的错误。
    ///
    /// 使用 `catch()` 来用新的发布者替换上游发布者的错误。
    ///
    /// 在下面的示例中，`catch()` 操作符处理上游发布者抛出的 `SimpleError`，并通过将错误替换为 `Just` 发布者来继续流。
    /// 这将发布一个单一的值并正常完成流。
    ///
    ///     struct SimpleError: Error {}
    ///     let numbers = [5, 4, 3, 2, 1, 0, 9, 8, 7, 6]
    ///     cancellable = numbers.publisher
    ///         .tryLast(where: {
    ///             guard $0 != 0 else { throw SimpleError() }
    ///             return true
    ///         })
    ///         .catch { error in
    ///             Just(-1)
    ///         }
    ///         .sink { print("\($0)") }
    ///         // 打印: -1
    ///
    /// 背压说明: 此发布者通过将 `request` 和 `cancel` 传递到上游。在接收到错误后，发布者将任何未满足的需求发送给新的 `Publisher`。
    ///
    /// - SeeAlso: `replaceError`
    /// - Parameter handler: 接受上游失败作为输入的闭包，并返回一个发布者，以替换上游发布者。
    /// - Returns: 一个处理上游发布者错误的发布者，通过用另一个发布者替换失败的发布者。

    public func `catch`<NewPublisher: Publisher>(
        _ handler: @escaping (Failure) -> NewPublisher
    ) -> Publishers.Catch<Self, NewPublisher>
    // NewPublisher.Output == Output, 保证了下游节点, 还是获取到同样类型的数据.
        where NewPublisher.Output == Output
    {
        return .init(upstream: self, handler: handler)
    }

    /// Handles errors from an upstream publisher by either replacing it with another
    /// publisher or throwing a new error.
    ///
    /// Use `tryCatch(_:)` to decide how to handle from an upstream publisher by either
    /// replacing the publisher with a new publisher, or throwing a new error.
    ///
    /// In the example below, an array publisher emits values that a `tryMap(_:)` operator
    /// evaluates to ensure the values are greater than zero. If the values aren’t greater
    /// than zero, the operator throws an error to the downstream subscriber to let it
    /// know there was a problem. The subscriber, `tryCatch(_:)`, replaces the error with
    /// a new publisher using ``Just`` to publish a final value before the stream ends
    /// normally.
    ///
    ///     enum SimpleError: Error { case error }
    ///     var numbers = [5, 4, 3, 2, 1, -1, 7, 8, 9, 10]
    ///
    ///     cancellable = numbers.publisher
    ///         .tryMap { v in
    ///             if v > 0 {
    ///                 return v
    ///             } else {
    ///                 throw SimpleError.error
    ///             }
    ///         }
    ///         .tryCatch { error in
    ///             Just(0) // Send a final value before completing normally.
    ///                     // Alternatively, throw a new error to terminate the stream.
    ///     }
    ///       .sink(receiveCompletion: { print ("Completion: \($0).") },
    ///             receiveValue: { print ("Received \($0).") })
    ///     //    Received 5.
    ///     //    Received 4.
    ///     //    Received 3.
    ///     //    Received 2.
    ///     //    Received 1.
    ///     //    Received 0.
    ///     //    Completion: finished.
    ///
    /// - Parameter handler: A throwing closure that accepts the upstream failure as
    ///   input. This closure can either replace the upstream publisher with a new one,
    ///   or throw a new error to the downstream subscriber.
    /// - Returns: A publisher that handles errors from an upstream publisher by replacing
    ///   the failed publisher with another publisher, or an error.
    /// 通过替换或抛出新错误处理上游发布者的错误。
    ///
    /// 使用 `tryCatch(_:)` 来决定如何处理上游发布者的错误，可以选择替换发布者为一个新的发布者，或者抛出一个新的错误。
    ///
    /// 在下面的示例中，一个数组发布者发出值，`tryMap(_:)` 操作符评估这些值以确保它们大于零。
    /// 如果值不大于零，操作符会向下游订阅者抛出一个错误以通知它存在问题。
    /// 订阅者 `tryCatch(_:)` 通过使用 ``Just`` 替换错误，以在流正常结束之前发布最终值。
    ///
    ///     enum SimpleError: Error { case error }
    ///     var numbers = [5, 4, 3, 2, 1, -1, 7, 8, 9, 10]
    ///
    ///     cancellable = numbers.publisher
    ///         .tryMap { v in
    ///             if v > 0 {
    ///                 return v
    ///             } else {
    ///                 throw SimpleError.error
    ///             }
    ///         }
    ///         .tryCatch { error in
    ///             Just(0) // 在正常完成之前发送最终值。
    ///                     // 或者，抛出一个新错误来终止流。
    ///         }
    ///         .sink(receiveCompletion: { print ("Completion: \($0).") },
    ///               receiveValue: { print ("Received \($0).") })
    ///     //    Received 5.
    ///     //    Received 4.
    ///     //    Received 3.
    ///     //    Received 2.
    ///     //    Received 1.
    ///     //    Received 0.
    ///     //    Completion: finished.
    ///
    /// - Parameter handler: 一个可抛出的闭包，接受上游失败作为输入。
    ///   此闭包可以选择替换上游发布者为一个新的发布者，或者向下游订阅者抛出新错误。
    /// - Returns: 一个发布者，通过替换失败的发布者为另一个发布者或者一个错误来处理上游发布者的错误。

    public func tryCatch<NewPublisher: Publisher>(
        _ handler: @escaping (Failure) throws -> NewPublisher
    ) -> Publishers.TryCatch<Self, NewPublisher>
        where NewPublisher.Output == Output
    {
        return .init(upstream: self, handler: handler)
    }
}

extension Publishers {

    /// A publisher that handles errors from an upstream publisher by replacing the failed
    /// publisher with another publisher.
    public struct Catch<Upstream: Publisher, NewPublisher: Publisher>: Publisher
        where Upstream.Output == NewPublisher.Output
    {
        public typealias Output = Upstream.Output

        // 下游的错误类型变化了.
        public typealias Failure = NewPublisher.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that accepts the upstream failure as input and returns a publisher
        /// to replace the upstream publisher.
        public let handler: (Upstream.Failure) -> NewPublisher

        /// Creates a publisher that handles errors from an upstream publisher by
        /// replacing the failed publisher with another publisher.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - handler: A closure that accepts the upstream failure as input and returns
        ///     a publisher to replace the upstream publisher.
        public init(upstream: Upstream,
                    handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.upstream = upstream
            self.handler = handler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, handler: handler)
            let uncaughtS = Inner.UncaughtS(inner: inner)
            upstream.subscribe(uncaughtS)
        }
    }

    /// A publisher that handles errors from an upstream publisher by replacing
    /// the failed publisher with another publisher or producing a new error.
    ///
    /// Because this publisher’s handler can throw an error, `Publishers.TryCatch` defines
    /// its `Failure` type as `Error`. This is different from `Publishers.Catch`, which
    /// gets its failure type from the replacement publisher.
    public struct TryCatch<Upstream: Publisher, NewPublisher: Publisher>: Publisher
        where Upstream.Output == NewPublisher.Output
    {
        public typealias Output = Upstream.Output

        // 错误类型变了.
        public typealias Failure = Error

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that accepts the upstream failure as input and either returns
        /// a publisher to replace the upstream publisher or throws an error.
        public let handler: (Upstream.Failure) throws -> NewPublisher

        /// Creates a publisher that handles errors from an upstream publisher by
        /// replacing the failed publisher with another publisher or by throwing an error.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - handler: A closure that accepts the upstream failure as input and either
        ///     returns a publisher to replace the upstream publisher. If this closure
        ///     throws an error, the publisher terminates with the thrown error.
        public init(upstream: Upstream,
                    handler: @escaping (Upstream.Failure) throws -> NewPublisher) {
            self.upstream = upstream
            self.handler = handler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            let inner = Inner(downstream: subscriber, handler: handler)
            let uncaughtS = Inner.UncaughtS(inner: inner)
            upstream.subscribe(uncaughtS)
        }
    }
}

extension Publishers.Catch {
    // Inner 会被两个 struct 引用. 所以, 状态要保存在 Inner 里面.
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output,
              Downstream.Failure == NewPublisher.Failure
    {
        // 没有发生错误之前, 是这个 UncaughtS 充当 Subscription.
        struct UncaughtS: Subscriber,
                          CustomStringConvertible,
                          CustomReflectable,
                          CustomPlaygroundDisplayConvertible
        {
            typealias Input = Upstream.Output

            typealias Failure = Upstream.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePre(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePre(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                return inner.receivePre(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        struct CaughtS: Subscriber,
                        CustomStringConvertible,
                        CustomReflectable,
                        CustomPlaygroundDisplayConvertible
        {
            typealias Input = NewPublisher.Output

            typealias Failure = NewPublisher.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePost(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePost(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                inner.receivePost(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        private enum State {
            case pendingPre
            case pre(Subscription)
            case pendingPost
            case post(Subscription)
            case cancelled
        }

        private let lock = UnfairLock.allocate()

        private var demand = Subscribers.Demand.none

        private var state = State.pendingPre

        private let downstream: Downstream

        private let handler: (Upstream.Failure) -> NewPublisher

        init(downstream: Downstream,
             handler: @escaping (Upstream.Failure) -> NewPublisher) {
            self.downstream = downstream
            self.handler = handler
        }

        deinit {
            lock.deallocate()
        }

        func receivePre(subscription: Subscription) {
            lock.lock()
            guard case .pendingPre = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .pre(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receivePre(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            demand -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            lock.lock()
            demand += newDemand
            lock.unlock()
            return newDemand
        }

        func receivePre(completion: Subscribers.Completion<Upstream.Failure>) {
            switch completion {
            case .finished:
                lock.lock()
                switch state {
                case .pre:
                    state = .cancelled
                    lock.unlock()
                    downstream.receive(completion: .finished)
                case .pendingPre, .pendingPost, .post, .cancelled:
                    lock.unlock()
                }
            case .failure(let error):
                lock.lock()
                switch state {
                case .pre:
                    state = .pendingPost
                    lock.unlock()
                    // 这里发生了切换.
                    handler(error).subscribe(CaughtS(inner: self))
                case .cancelled:
                    lock.unlock()
                case .pendingPre, .post, .pendingPost:
                    completionBeforeSubscription()
                }
            }
        }

        func receivePost(subscription: Subscription) {
            lock.lock()
            guard case .pendingPost = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 上游发送过来 subscription, 才会发生改变.
            // 然后还会继续使用, 之前存储的 demand.
            state = .post(subscription)
            let demand = self.demand
            lock.unlock()
            if demand > 0 {
                subscription.request(demand)
            }
        }

        func receivePost(_ input: NewPublisher.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receivePost(completion: Subscribers.Completion<NewPublisher.Failure>) {
            lock.lock()
            guard case .post = state else {
                lock.unlock()
                return
            }
            state = .cancelled
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            switch state {
            case .pendingPre:
                // The client is only able to call the `request` method after we've sent
                // `self` downstream. We only do it in the `receivePre(subscription:)`
                // method, after setting `state` to `pre`.
                // After that `state` never becomes `pendingPre`.
                requestBeforeSubscription()
            case let .pre(subscription):
                self.demand += demand
                lock.unlock()
                subscription.request(demand)
            case .pendingPost:
                self.demand += demand
                lock.unlock()
            case let .post(subscription):
                lock.unlock()
                subscription.request(demand)
            case .cancelled:
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            switch state {
            case let .pre(subscription), let .post(subscription):
                state = .cancelled
                lock.unlock()
                subscription.cancel()
            case .pendingPre, .pendingPost, .cancelled:
                lock.unlock()
            }
        }

        var description: String { return "Catch" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryCatch {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output,
              Downstream.Failure == Error
    {
        struct UncaughtS: Subscriber,
                          CustomStringConvertible,
                          CustomReflectable,
                          CustomPlaygroundDisplayConvertible
        {
            typealias Input = Upstream.Output

            typealias Failure = Upstream.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePre(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePre(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                return inner.receivePre(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        struct CaughtS: Subscriber,
                        CustomStringConvertible,
                        CustomReflectable,
                        CustomPlaygroundDisplayConvertible
        {
            typealias Input = NewPublisher.Output

            typealias Failure = NewPublisher.Failure

            let inner: Inner

            var combineIdentifier: CombineIdentifier { return inner.combineIdentifier }

            func receive(subscription: Subscription) {
                inner.receivePost(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return inner.receivePost(input)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                inner.receivePost(completion: completion)
            }

            var description: String { return inner.description }

            var customMirror: Mirror { return inner.customMirror }

            var playgroundDescription: Any { return description }
        }

        private enum State {
            case pendingPre
            case pre(Subscription)
            case pendingPost
            case post(Subscription)
            case cancelled
        }

        private let lock = UnfairLock.allocate()

        private var demand = Subscribers.Demand.none

        private var state = State.pendingPre

        private let downstream: Downstream

        private let handler: (Upstream.Failure) throws -> NewPublisher

        init(downstream: Downstream,
             handler: @escaping (Upstream.Failure) throws -> NewPublisher) {
            self.downstream = downstream
            self.handler = handler
        }

        deinit {
            lock.deallocate()
        }

        func receivePre(subscription: Subscription) {
            lock.lock()
            guard case .pendingPre = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .pre(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receivePre(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            demand -= 1
            lock.unlock()
            let newDemand = downstream.receive(input)
            lock.lock()
            demand += newDemand
            lock.unlock()
            return newDemand
        }

        func receivePre(completion: Subscribers.Completion<Upstream.Failure>) {
            switch completion {
            case .finished:
                lock.lock()
                switch state {
                case .pre:
                    state = .cancelled
                    lock.unlock()
                    downstream.receive(completion: .finished)
                case .pendingPre, .pendingPost, .post, .cancelled:
                    lock.unlock()
                }
            case .failure(let error):
                lock.lock()
                switch state {
                case .pre:
                    state = .pendingPost
                    lock.unlock()
                    do {
                        // 如果, handler(error) 也发生了错误, 那么下游直接就收到这个错误.
                        // 正是因为这里, 下游要变为 Error 的, 因为 handler(error) 这里的错误没有办法固定类型. 
                        try handler(error).subscribe(CaughtS(inner: self))
                    } catch let anotherError {
                        lock.lock()
                        state = .cancelled
                        lock.unlock()
                        downstream.receive(completion: .failure(anotherError))
                    }
                case .cancelled:
                    lock.unlock()
                case .pendingPre, .post, .pendingPost:
                    completionBeforeSubscription()
                }
            }
        }

        func receivePost(subscription: Subscription) {
            lock.lock()
            guard case .pendingPost = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .post(subscription)
            let demand = self.demand
            lock.unlock()
            if demand > 0 {
                subscription.request(demand)
            }
        }

        func receivePost(_ input: NewPublisher.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receivePost(completion: Subscribers.Completion<NewPublisher.Failure>) {
            lock.lock()
            guard case .post = state else {
                lock.unlock()
                return
            }
            state = .cancelled
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            switch state {
            case .pendingPre:
                // The client is only able to call the `request` method after we've sent
                // `self` downstream. We only do it in the `receivePre(subscription:)`
                // method, after setting `state` to `pre`.
                // After that `state` never becomes `pendingPre`.
                requestBeforeSubscription()
            case let .pre(subscription):
                self.demand += demand
                lock.unlock()
                subscription.request(demand)
            case .pendingPost:
                self.demand += demand
                lock.unlock()
            case let .post(subscription):
                lock.unlock()
                subscription.request(demand)
            case .cancelled:
                lock.unlock()
            }
        }

        func cancel() {
            lock.lock()
            switch state {
            case let .pre(subscription), let .post(subscription):
                state = .cancelled
                lock.unlock()
                subscription.cancel()
            case .pendingPre, .pendingPost, .cancelled:
                lock.unlock()
            }
        }

        var description: String { return "TryCatch" }

        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}

private func completionBeforeSubscription(file: StaticString = #file,
                                          line: UInt = #line) -> Never {
    fatalError("Unexpected state: received completion but do not have subscription",
               file: file,
               line: line)
}

private func requestBeforeSubscription(file: StaticString = #file,
                                       line: UInt = #line) -> Never {
    fatalError("Unexpected state: request before subscription sent",
               file: file,
               line: line)
}
