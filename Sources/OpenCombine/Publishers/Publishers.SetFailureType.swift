//

extension Publishers {
    /// A publisher that appears to send a specified failure type.
    
    /// The publisher cannot actually fail with the specified type and instead
    /// just finishes normally. Use this publisher type when you need to match
    /// the error types for two mismatched publishers.
    
    // 只有, 原本的 Failure Type 是 Never 才可以使用该方法.
    public struct SetFailureType<Upstream: Publisher, Failure: Error>: Publisher
    where Upstream.Failure == Never
    {
        public typealias Output = Upstream.Output
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// Creates a publisher that appears to send a specified failure type.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
        
        public func setFailureType<NewFailure: Error>(
            to failure: NewFailure.Type
        ) -> Publishers.SetFailureType<Upstream, NewFailure> {
            return .init(upstream: upstream)
        }
    }
}

extension Publishers.SetFailureType: Equatable where Upstream: Equatable {}

// 只有, 原本的是 Never 类型, 才可以使用该方法.
extension Publisher where Failure == Never {
    
    /// Changes the failure type declared by the upstream publisher.
    ///
    /// Use `setFailureType(to:)` when you need set the error type of a publisher that
    /// cannot fail.
    
    /// Conversely, if the upstream can fail, you would use `mapError(_:)` to provide
    /// instructions on converting the error types to needed by the downstream publisher’s
    /// inputs.
    
    /// The following example has two publishers with mismatched error types: `pub1`’s
    /// error type is `Never`, and `pub2`’s error type is `Error`. Because of
    /// the mismatch, the `combineLatest(_:)` operator requires that `pub1` use
    /// `setFailureType(to:)` to make it appear that `pub1` can produce the `Error` type,
    /// like `pub2` can.
    
    // 产生了需求, 两个 Publisher 需要 Error 匹配才能一起使用.
    // 而 Never 是可以兼容 Error, 所以, Never 主动将自己变化为 Error 类型的.
    ///     let pub1 = [0, 1, 2, 3, 4, 5].publisher
    ///     let pub2 = CurrentValueSubject<Int, Error>(0)
    ///     let cancellable = pub1
    ///         .setFailureType(to: Error.self)
    ///         .combineLatest(pub2)
    ///         .sink(
    ///             receiveCompletion: { print ("completed: \($0)") },
    ///             receiveValue: { print ("value: \($0)")}
    ///          )
    ///
    ///     // Prints: "value: (5, 0)".
    ///
    /// - Parameter failureType: The `Failure` type presented by this publisher.
    /// - Returns: A publisher that appears to send the specified failure type.
    public func setFailureType<NewFailure: Error>(
        to failureType: NewFailure.Type
    ) -> Publishers.SetFailureType<Self, NewFailure> {
        return .init(upstream: self)
    }
}

extension Publishers.SetFailureType {
    
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input, Failure == Downstream.Failure
    {
        private let downstream: Downstream
        let combineIdentifier = CombineIdentifier()
        
        fileprivate init(downstream: Downstream) {
            self.downstream = downstream
        }
        
        // Forward 操作.
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }
        
        // Fail 是 Never.
        // Failure 根本没有真正的使用到. 仅仅是让编译通过. 
        func receive(completion: Subscribers.Completion<Never>) {
            downstream.receive(completion: .finished)
        }
        
        var description: String { return "SetFailureType" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}
