//
//  Publishers.SetFailureType.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.07.2019.
//

extension Publishers {

    /// A publisher that appears to send a specified failure type.
    ///
    /// The publisher cannot actually fail with the specified type and instead
    /// just finishes normally. Use this publisher type when you need to match
    /// the error types for two mismatched publishers.
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

extension Publisher where Failure == Never {

    /// Changes the failure type declared by the upstream publisher.
    ///
    /// Use `setFailureType(to:)` when you need set the error type of a publisher that
    /// cannot fail.
    ///
    /// Conversely, if the upstream can fail, you would use `mapError(_:)` to provide
    /// instructions on converting the error types to needed by the downstream publisher’s
    /// inputs.
    ///
    /// The following example has two publishers with mismatched error types: `pub1`’s
    /// error type is `Never`, and `pub2`’s error type is `Error`. Because of
    /// the mismatch, the `combineLatest(_:)` operator requires that `pub1` use
    /// `setFailureType(to:)` to make it appear that `pub1` can produce the `Error` type,
    /// like `pub2` can.
    ///
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
    
    /// 改变上游发布者声明的失败类型。
    ///
    /// 在需要设置无法失败的发布者的错误类型时，请使用 `setFailureType(to:)`。
    ///
    /// 相反，如果上游可能失败，您将使用 `mapError(_:)` 来提供将错误类型转换为下游发布者所需类型的说明。
    ///
    /// 以下示例有两个具有不匹配错误类型的发布者：`pub1` 的错误类型是 `Never`，而 `pub2` 的错误类型是 `Error`。
    /// 由于不匹配，`combineLatest(_:)` 操作符要求 `pub1` 使用 `setFailureType(to:)`，
    /// 使其看起来好像 `pub1` 可以生成 `Error` 类型，就像 `pub2` 一样。
    ///
    ///     let pub1 = [0, 1, 2, 3, 4, 5].publisher
    ///     let pub2 = CurrentValueSubject<Int, Error>(0)
    ///     let cancellable = pub1
    ///         .setFailureType(to: Error.self)
    ///         .combineLatest(pub2)
    ///         .sink(
    ///             receiveCompletion: { print("completed: \($0)") },
    ///             receiveValue: { print("value: \($0)")}
    ///          )
    ///
    ///     // 输出: "value: (5, 0)"。
    ///
    /// - Parameter failureType: 由此发布者呈现的 `Failure` 类型。
    /// - Returns: 一个看起来会发送指定失败类型的发布者。

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
        // 所有的都是透传, 只是将泛型的类型进行了改变. 
        private let downstream: Downstream
        let combineIdentifier = CombineIdentifier()

        fileprivate init(downstream: Downstream) {
            self.downstream = downstream
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

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
