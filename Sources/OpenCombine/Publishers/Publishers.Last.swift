//
//  Publishers.Last.swift
//  
//
//  Created by Joseph Spadafora on 7/9/19.
//

extension Publisher {

    /// Publishes the last element of a stream, after the stream finishes.
    ///
    /// Use `last()` when you need to emit only the last element from an upstream
    /// publisher.
    ///
    /// In the example below, the range publisher only emits the last element from
    /// the sequence publisher, `10`, then finishes normally.
    ///
    ///     let numbers = (-10...10)
    ///     cancellable = numbers.publisher
    ///         .last()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "10"
    ///
    /// - Returns: A publisher that only publishes the last element of a stream.
    /// 在流完成后发布流的最后一个元素。
    ///
    /// 当需要仅从上游发布者发出最后一个元素时，请使用 `last()`。
    ///
    /// 在下面的示例中，范围发布者仅从序列发布者发出最后一个元素 `10`，然后正常完成。
    ///
    ///     let numbers = (-10...10)
    ///     cancellable = numbers.publisher
    ///         .last()
    ///         .sink { print("\($0)") }
    ///
    ///     // 输出: "10"
    ///
    /// - Returns: 一个只发布流的最后一个元素的发布者。

    public func last() -> Publishers.Last<Self> {
        return .init(upstream: self)
    }

    /// Publishes the last element of a stream that satisfies a predicate closure,
    /// after upstream finishes.
    ///
    /// Use `last(where:)` when you need to republish only the last element of a stream
    /// that satisfies a closure you specify.
    ///
    /// In the example below, a range publisher emits the last element that satisfies
    /// the closure’s criteria, then finishes normally:
    ///
    ///     let numbers = (-10...10)
    ///     cancellable = numbers.publisher
    ///         .last { $0 < 6 }
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "5"
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the last element satisfying the given
    ///   predicate.
    public func last(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.LastWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes the last element of a stream that satisfies an error-throwing predicate
    /// closure, after the stream finishes.
    ///
    /// Use `tryLast(where:)` when you need to republish the last element that satisfies
    /// an error-throwing closure you specify. If the predicate closure throws an error,
    /// the publisher fails.
    ///
    /// In the example below, a publisher emits the last element that satisfies
    /// the error-throwing closure, then finishes normally:
    ///
    ///     struct RangeError: Error {}
    ///
    ///     let numbers = [-62, 1, 6, 10, 9, 22, 41, -1, 5]
    ///     cancellable = numbers.publisher
    ///         .tryLast {
    ///             guard 0 != 0  else {throw RangeError()}
    ///             return true
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)", terminator: " ") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///         )
    ///     // Prints: "5 completion: finished"
    ///     // If instead the numbers array had contained a `0`, the `tryLast` operator
    ///     // would terminate publishing with a RangeError."
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the last element satisfying the given
    ///   predicate.
    public func tryLast(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryLastWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that only publishes the last element of a stream,
    /// after the stream finishes.
    public struct Last<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }

    /// A publisher that only publishes the last element of a stream that satisfies
    /// a predicate closure, once the stream finishes.
    public struct LastWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether to publish an element.
        public let predicate: (Upstream.Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }

    /// A publisher that only publishes the last element of a stream that satisfies
    /// an error-throwing predicate closure, once the stream finishes.
    public struct TryLastWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether to publish an element.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Error, Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
}

extension Publishers.Last: Equatable where Upstream: Equatable {}

extension Publishers.Last {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         Void>
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            super.init(downstream: downstream, initial: nil, reduce: ())
        }

        // 利用了 ReduceProducer, ReduceProducer 会在接受到完成事件的时候, 把 Result 的值传递过去.
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result = newValue
            return .continue
        }

        override var description: String { return "Last" }
    }
}

extension Publishers.LastWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output) -> Bool>
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) -> Bool) {
            super.init(downstream: downstream, initial: nil, reduce: predicate)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if reduce(newValue) {
                result = newValue
            }
            return .continue
        }

        override var description: String { return "LastWhere" }
    }
}

extension Publishers.TryLastWhere {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Bool>
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) throws -> Bool) {
            super.init(downstream: downstream, initial: nil, reduce: predicate)
        }

        // 所有的这种 try, 都是一个处理的结果
        // 就是在 receive value 的时候, 进行错误的处理. 
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            do {
                if try reduce(newValue) {
                    result = newValue
                }
                return .continue
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryLastWhere" }
    }
}
