//
//  Publishers.CompactMap.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.07.2019.
//

extension Publisher {

    /// Calls a closure with each received element and publishes any returned optional
    /// that has a value.
    ///
    /// OpenCombine’s `compactMap(_:)` operator performs a function similar to that of
    /// `compactMap(_:)` in the Swift standard library: the `compactMap(_:)` operator in
    /// OpenCombine removes `nil` elements in a publisher’s stream and republishes
    /// non-`nil` elements to the downstream subscriber.
    ///
    /// The example below uses a range of numbers as the source for a collection based
    /// publisher. The `compactMap(_:)` operator consumes each element from the `numbers`
    /// publisher attempting to access the dictionary using the element as the key.
    /// If the example’s dictionary returns a `nil`, due to a non-existent key,
    /// `compactMap(_:)` filters out the `nil` (missing) elements.
    ///
    ///     let numbers = (0...5)
    ///     let romanNumeralDict: [Int : String] =
    ///         [1: "I", 2: "II", 3: "III", 5: "V"]
    ///
    ///     cancellable = numbers.publisher
    ///         .compactMap { romanNumeralDict[$0] }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "I II III V"
    ///
    /// - Parameter transform: A closure that receives a value and returns an optional
    ///   value.
    /// - Returns: Any non-`nil` optional results of the calling the supplied closure.
    /// 对每个接收到的元素调用闭包，并发布任何具有值的返回的可选项。
    ///
    /// OpenCombine 的 `compactMap(_:)` 运算符执行类似于 Swift 标准库中的 `compactMap(_:)` 的功能：
    /// OpenCombine 中的 `compactMap(_:)` 运算符会从发布者的流中移除 `nil` 元素，并将非 `nil` 元素重新发布给下游订阅者。
    ///
    /// 下面的示例使用数字范围作为基于集合的发布者的源。`compactMap(_:)` 运算符消耗 `numbers` 发布者的每个元素，尝试使用元素作为键访问字典。
    /// 如果示例的字典由于不存在的键返回 `nil`，`compactMap(_:)` 将过滤掉 `nil`（缺失）元素。
    ///
    ///     let numbers = (0...5)
    ///     let romanNumeralDict: [Int: String] =
    ///         [1: "I", 2: "II", 3: "III", 5: "V"]
    ///
    ///     cancellable = numbers.publisher
    ///         .compactMap { romanNumeralDict[$0] }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // 输出: "I II III V"
    ///
    /// - Parameter transform: 一个接收值并返回一个可选值的闭包。
    /// - Returns: 调用所提供闭包后的任何非 `nil` 可选结果。
    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }

    /// Calls an error-throwing closure with each received element and publishes any
    /// returned optional that has a value.
    ///
    /// Use `tryCompactMap(_:)` to remove `nil` elements from a publisher’s stream based
    /// on an error-throwing closure you provide. If the closure throws an error,
    /// the publisher cancels the upstream publisher and sends the thrown error to
    /// the downstream subscriber as a `Publisher.Failure`.
    ///
    /// The following example uses an array of numbers as the source for
    /// a collection-based publisher. A `tryCompactMap(_:)` operator consumes each integer
    /// from the publisher and uses a dictionary to transform the numbers from its Arabic
    /// to Roman numerals, as an optional `String`.
    ///
    /// If the closure called by `tryCompactMap(_:)` fails to look up a Roman numeral,
    /// it returns the optional String `(unknown)`.
    ///
    /// If the closure called by `tryCompactMap(_:)` determines the input is `0`, it
    /// throws an error. The `tryCompactMap(_:)` operator catches this error and stops
    /// publishing, sending a `Subscribers.Completion.failure(_:)` that wraps the error.
    ///
    ///     struct ParseError: Error {}
    ///     func romanNumeral(from: Int) throws -> String? {
    ///         let romanNumeralDict: [Int : String] =
    ///             [1: "I", 2: "II", 3: "III", 4: "IV", 5: "V"]
    ///         guard from != 0 else { throw ParseError() }
    ///         return romanNumeralDict[from]
    ///     }
    ///     let numbers = [6, 5, 4, 3, 2, 1, 0]
    ///     cancellable = numbers.publisher
    ///         .tryCompactMap { try romanNumeral(from: $0) }
    ///         .sink(
    ///               receiveCompletion: { print ("\($0)") },
    ///               receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "(Unknown) V IV III II I failure(ParseError())"
    ///
    /// - Parameter transform: An error-throwing closure that receives a value and returns
    ///   an optional value.
    /// - Returns: Any non-`nil` optional results of calling the supplied closure.
    /// 对每个接收到的元素调用一个可能抛出错误的闭包，并发布任何具有值的返回的可选项。
    ///
    /// 使用 `tryCompactMap(_:)` 来基于你提供的可能抛出错误的闭包移除发布者流中的 `nil` 元素。
    /// 如果闭包抛出错误，发布者将取消上游发布者并将抛出的错误作为 `Publisher.Failure` 发送给下游订阅者。
    ///
    /// 以下示例使用数字数组作为基于集合的发布者的源。`tryCompactMap(_:)` 运算符消耗发布者的每个整数，并使用字典将数字从阿拉伯数字转换为罗马数字，作为可选的 `String`。
    ///
    /// 如果 `tryCompactMap(_:)` 调用的闭包未能查找到罗马数字，它将返回可选的字符串 `(Unknown)`。
    ///
    /// 如果 `tryCompactMap(_:)` 调用的闭包确定输入为 `0`，它将抛出一个错误。`tryCompactMap(_:)` 运算符捕获此错误并停止发布，发送包装错误的 `Subscribers.Completion.failure(_:)`。
    ///
    ///     struct ParseError: Error {}
    ///     func romanNumeral(from: Int) throws -> String? {
    ///         let romanNumeralDict: [Int : String] =
    ///             [1: "I", 2: "II", 3: "III", 4: "IV", 5: "V"]
    ///         guard from != 0 else { throw ParseError() }
    ///         return romanNumeralDict[from]
    ///     }
    ///     let numbers = [6, 5, 4, 3, 2, 1, 0]
    ///     cancellable = numbers.publisher
    ///         .tryCompactMap { try romanNumeral(from: $0) }
    ///         .sink(
    ///               receiveCompletion: { print ("\($0)") },
    ///               receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // 输出: "(Unknown) V IV III II I failure(ParseError())"
    ///
    /// - Parameter transform: 一个可能抛出错误的闭包，接收一个值并返回一个可选值。
    /// - Returns: 调用所提供闭包后的任何非 `nil` 可选结果。

    public func tryCompactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }
}

extension Publishers.CompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult?
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).flatMap(transform) })
    }

    public func map<ElementOfResult>(
        _ transform: @escaping (Output) -> ElementOfResult
    ) -> Publishers.CompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { self.transform($0).map(transform) })
    }
}

extension Publishers.TryCompactMap {

    public func compactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Upstream, ElementOfResult> {
        return .init(upstream: upstream,
                     transform: { try self.transform($0).flatMap(transform) })
    }
}

extension Publishers {

    /// A publisher that republishes all non-`nil` results of calling a closure
    /// with each received element.
    public struct CompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that receives values from the upstream publisher
        /// and returns optional values.
        public let transform: (Upstream.Output) -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: transform))
        }
    }

    /// A publisher that republishes all non-`nil` results of calling an error-throwing
    /// closure with each received element.
    public struct TryCompactMap<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// An error-throwing closure that receives values from the upstream publisher
        /// and returns optional values.
        ///
        /// If this closure throws an error, the publisher fails.
        public let transform: (Upstream.Output) throws -> Output?

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) throws -> Output?) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: transform))
        }
    }
}

extension Publishers.CompactMap {
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let filter: (Input) -> Downstream.Input?

        let combineIdentifier = CombineIdentifier()

        init(downstream: Downstream, filter: @escaping (Input) -> Downstream.Input?) {
            self.downstream = downstream
            self.filter = filter
        }

        // 透传.
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            // 如果不符合要求, 就不传递, 但是拉取一个数据
            // 如果符合要求, 就透传
            if let output = filter(input) {
                return downstream.receive(output)
            }
            return .max(1)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        var description: String { return "CompactMap" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryCompactMap {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Output,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Output?>
        where Downstream.Failure == Error, Downstream.Input == Output
    {
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Output?, Error> {
            do {
                return try .continue(filter(newValue))
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryCompactMap" }
    }
}
