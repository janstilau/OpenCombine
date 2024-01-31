//
//  Publishers.MapError.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

extension Publishers {

    /// A publisher that converts any failure from the
    /// upstream publisher into a new error.
    
    /// 一个将上游发布者的任何失败转换为新错误的发布者。
    public struct MapError<Upstream: Publisher, Failure: Error>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that converts the upstream failure into a new error.
        public let transform: (Upstream.Failure) -> Failure

        public init(upstream: Upstream, _ map: @escaping (Upstream.Failure) -> Failure) {
            self.upstream = upstream
            self.transform = map
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, map: transform))
        }
    }
}

extension Publisher {

    /// Converts any failure from the upstream publisher into a new error.
    ///
    /// Use the `mapError(_:)` operator when you need to replace one error type with
    /// another, or where a downstream operator needs the error types of its inputs to
    /// match.
    ///
    /// The following example uses a `tryMap(_:)` operator to divide `1` by each element
    /// produced by a sequence publisher. When the publisher produces a `0`,
    /// the `tryMap(_:)` fails with a `DivisionByZeroError`. The `mapError(_:)` operator
    /// converts this into a `MyGenericError`.
    ///
    ///     struct DivisionByZeroError: Error {}
    ///     struct MyGenericError: Error { var wrappedError: Error }
    ///
    ///     func myDivide(_ dividend: Double, _ divisor: Double) throws -> Double {
    ///         guard divisor != 0 else { throw DivisionByZeroError() }
    ///         return dividend / divisor
    ///     }
    ///
    ///     let divisors: [Double] = [5, 4, 3, 2, 1, 0]
    ///     divisors.publisher
    ///         .tryMap { try myDivide(1, $0) }
    ///         .mapError { MyGenericError(wrappedError: $0) }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") ,
    ///             receiveValue: { print ("value: \($0)") }
    ///          )
    ///
    ///     // Prints:
    ///     //   value: 0.2
    ///     //   value: 0.25
    ///     //   value: 0.3333333333333333
    ///     //   value: 0.5
    ///     //   value: 1.0
    ///     //   completion: failure(MyGenericError(wrappedError: DivisionByZeroError()))"
    ///
    /// - Parameter transform: A closure that takes the upstream failure as a parameter
    ///   and returns a new error for the publisher to terminate with.
    /// - Returns: A publisher that replaces any upstream failure with a new error
    ///   produced by the `transform` closure.
    
    /// 将上游发布者的任何失败转换为新错误。
    ///
    /// 当需要用另一种错误类型替换错误，或者下游操作符需要其输入的错误类型匹配时，使用 `mapError(_:)` 操作符。
    ///
    /// 以下示例使用 `tryMap(_:)` 操作符将 `1` 除以由序列发布者产生的每个元素。当发布者产生 `0` 时，
    /// `tryMap(_:)` 会失败，并抛出一个 `DivisionByZeroError`。`mapError(_:)` 操作符将其转换为 `MyGenericError`。
    ///
    ///     struct DivisionByZeroError: Error {}
    ///     struct MyGenericError: Error { var wrappedError: Error }
    ///
    ///     func myDivide(_ dividend: Double, _ divisor: Double) throws -> Double {
    ///         guard divisor != 0 else { throw DivisionByZeroError() }
    ///         return dividend / divisor
    ///     }
    ///
    ///     let divisors: [Double] = [5, 4, 3, 2, 1, 0]
    ///     divisors.publisher
    ///         .tryMap { try myDivide(1, $0) }
    ///         // 主要是为了, 进行下游的 Error 类型的匹配.
    ///         .mapError { MyGenericError(wrappedError: $0) }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") ,
    ///             receiveValue: { print ("value: \($0)") }
    ///          )
    ///
    ///     // Prints:
    ///     //   value: 0.2
    ///     //   value: 0.25
    ///     //   value: 0.3333333333333333
    ///     //   value: 0.5
    ///     //   value: 1.0
    ///     //   completion: failure(MyGenericError(wrappedError: DivisionByZeroError()))"
    ///
    /// - Parameter transform: 一个接受上游失败作为参数的闭包，返回一个新错误，以终止发布者。
    /// - Returns: 一个发布者，用 `transform` 闭包产生的新错误替换任何上游失败。

    public func mapError<NewFailure: Error>(
        _ transform: @escaping (Failure) -> NewFailure
    ) -> Publishers.MapError<Self, NewFailure>
    {
        return Publishers.MapError(upstream: self, transform)
    }
}

extension Publishers.MapError {

    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let map: (Upstream.Failure) -> Downstream.Failure

        let combineIdentifier = CombineIdentifier()

        var description: String { return "MapError" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        init(downstream: Downstream,
             map: @escaping (Upstream.Failure) -> Downstream.Failure) {
            self.downstream = downstream
            self.map = map
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        // 在接受到完成事件的时候, 将对应的 Error 类型进行修改. 
        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(map(error)))
            }
        }
    }
}
