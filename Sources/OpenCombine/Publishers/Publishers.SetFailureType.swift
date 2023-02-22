extension Publishers {
    /// A publisher that appears to send a specified failure type.
    
    /// The publisher cannot actually fail with the specified type and instead
    /// just finishes normally. Use this publisher type when you need to match
    /// the error types for two mismatched publishers.
    
    // 只有, 原本的 Failure Type 是 Never 才可以使用该方法. 所以上游其实还是不会真的发送错误过来.
    // 这个方法, 主要是为了类型适配用的.
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
        
        /*
         只做上游数据到下游数据的逻辑重写, 不做 demand 的管理, 可以直接将上游转交给下游.
         从下游向上进行回溯, 是没有本类对象的.
         
         但是从上游进行数据的传递, 还是需要本类对象的.
         两条回路上的节点数量不同.
         一般来说, 从上到下的回溯是最全的. 
         */
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Never>) {
            switch  completion {
            case .finished:
                break
            case .failure(let failure): // failure 的类型是 Never.
//                print(failure)
                break
            }
            downstream.receive(completion: .finished)
        }
        
        
        
        
        var description: String { return "SetFailureType" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}
