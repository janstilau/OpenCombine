extension Publisher {

    /// Transforms all elements from the upstream publisher with a provided closure.
    ///
    /// OpenCombine’s `map(_:)` operator performs a function similar to that of `map(_:)`
    /// in the Swift standard library: it uses a closure to transform each element it
    /// receives from the upstream publisher. You use `map(_:)` to transform from one kind
    /// of element to another.
    ///
    /// The following example uses an array of numbers as the source for a collection
    /// based publisher. A `map(_:)` operator consumes each integer from the publisher and
    /// uses a dictionary to transform it from its Arabic numeral to a Roman equivalent,
    /// as a `String`.
    /// If the `map(_:)`’s closure fails to look up a Roman numeral, it returns the string
    /// `(unknown)`.
    ///
    ///     let numbers = [5, 4, 3, 2, 1, 0]
    ///     let romanNumeralDict: [Int : String] =
    ///        [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
    ///     cancellable = numbers.publisher
    ///         .map { romanNumeralDict[$0] ?? "(unknown)" }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "V IV III II I (unknown)"
    ///
    /// If your closure can throw an error, use OpenCombine’s `tryMap(_:)` operator
    /// instead.
    ///
    /// - Parameter transform: A closure that takes one element as its parameter and
    ///   returns a new element.
    /// - Returns: A publisher that uses the provided closure to map elements from
    ///   the upstream publisher to new elements that it then publishes.
    
    /// 使用提供的闭包转换上游发布者的所有元素。
    ///
    /// OpenCombine的 map(_:) 操作符执行的功能类似于Swift标准库中的 map(_:)：
    /// 它使用闭包来转换从上游发布者接收到的每个元素。您可以使用 map(_:) 将一种类型
    /// 的元素转换为另一种类型。
    ///
    /// 以下示例使用数字数组作为基于集合的发布者的源。map(_:) 操作符从发布者消耗每个整数，
    /// 并使用字典将其从阿拉伯数字转换为罗马数字的等效形式，作为 String。
    /// 如果 map(_:) 的闭包无法查找到罗马数字，它将返回字符串 (unknown)。
    ///
    /// let numbers = [5, 4, 3, 2, 1, 0]
    /// let romanNumeralDict: [Int : String] =
    /// [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
    /// cancellable = numbers.publisher
    /// .map { romanNumeralDict[$0] ?? "(unknown)" }
    /// .sink { print("($0)", terminator: " ") }
    ///
    /// // 输出: "V IV III II I (unknown)"
    ///
    /// 如果您的闭包可能引发错误，请改用OpenCombine的 tryMap(_:) 操作符。
    ///
    /// - Parameter transform: 接受一个元素作为其参数并返回一个新元素的闭包。
    /// - Returns: 一个使用提供的闭包将上游发布者的元素映射到新元素的发布者
    public func map<Result>(
        _ transform: @escaping (Output) -> Result
    ) -> Publishers.Map<Self, Result> {
        return Publishers.Map(upstream: self, transform: transform)
    }

    /// Transforms all elements from the upstream publisher with a provided error-throwing
    /// closure.
    ///
    /// OpenCombine’s `tryMap(_:)` operator performs a function similar to that of
    /// `map(_:)` in the Swift standard library: it uses a closure to transform each
    /// element it receives from the upstream publisher. You use `tryMap(_:)` to transform
    /// from one kind of element to another, and to terminate publishing when the map’s
    /// closure throws an error.
    ///
    /// The following example uses an array of numbers as the source for a collection
    /// based publisher. A `tryMap(_:)` operator consumes each integer from the publisher
    /// and uses a dictionary to transform it from its Arabic numeral to a Roman
    /// equivalent, as a `String`.
    /// If the `tryMap(_:)`’s closure fails to look up a Roman numeral, it throws
    /// an error. The `tryMap(_:)` operator catches this error and terminates publishing,
    /// sending a `Subscribers.Completion.failure(_:)` that wraps the error.
    ///
    ///     struct ParseError: Error {}
    ///     func romanNumeral(from:Int) throws -> String {
    ///         let romanNumeralDict: [Int : String] =
    ///             [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
    ///         guard let numeral = romanNumeralDict[from] else {
    ///             throw ParseError()
    ///         }
    ///         return numeral
    ///     }
    ///     let numbers = [5, 4, 3, 2, 1, 0]
    ///     cancellable = numbers.publisher
    ///         .tryMap { try romanNumeral(from: $0) }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "V IV III II I completion: failure(ParseError())"
    ///
    /// If your closure doesn’t throw, use `map(_:)` instead.
    ///
    /// - Parameter transform: A closure that takes one element as its parameter and
    ///   returns a new element. If the closure throws an error, the publisher fails with
    ///   the thrown error.
    /// - Returns: A publisher that uses the provided closure to map elements from
    ///   the upstream publisher to new elements that it then publishes.
    
    /// 使用提供的可能引发错误的闭包转换上游发布者的所有元素。
    ///
    /// OpenCombine的 tryMap(_:) 操作符执行的功能类似于Swift标准库中的 map(_:)：
    /// 它使用闭包来转换从上游发布者接收到的每个元素。您可以使用 tryMap(_:) 将一种类型
    /// 的元素转换为另一种类型，并在映射的闭包引发错误时终止发布。
    ///
    /// 以下示例使用数字数组作为基于集合的发布者的源。tryMap(_:) 操作符从发布者消耗每个整数，
    /// 并使用字典将其从阿拉伯数字转换为罗马数字的等效形式，作为 String。
    /// 如果 tryMap(_:) 的闭包无法查找到罗马数字，它将引发错误。tryMap(_:) 操作符捕获此错误并终止发布，
    /// 发送包装错误的 Subscribers.Completion.failure(_:)。
    ///
    /// struct ParseError: Error {}
    /// func romanNumeral(from:Int) throws -> String {
    /// let romanNumeralDict: [Int : String] =
    /// [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
    /// guard let numeral = romanNumeralDict[from] else {
    /// throw ParseError()
    /// }
    /// return numeral
    /// }
    /// let numbers = [5, 4, 3, 2, 1, 0]
    /// cancellable = numbers.publisher
    /// .tryMap { try romanNumeral(from: $0) }
    /// .sink(
    /// receiveCompletion: { print ("completion: ($0)") },
    /// receiveValue: { print ("($0)", terminator: " ") }
    /// )
    ///
    /// // 输出: "V IV III II I completion: failure(ParseError())"
    ///
    /// 如果您的闭包不会引发错误，请改用 map(_:)。
    ///
    /// - Parameter transform: 接受一个元素作为其参数并返回一个新元素的闭包。
    /// 如果闭包引发错误，发布者将以引发的错误失败。
    /// - Returns: 一个使用提供的闭包将上游发布者的元素映射到新元素的发布者。
    public func tryMap<Result>(
        _ transform: @escaping (Output) throws -> Result
    ) -> Publishers.TryMap<Self, Result> {
        return Publishers.TryMap(upstream: self, transform: transform)
    }

    /// Replaces `nil` elements in the stream with the provided element.
    ///
    /// The `replaceNil(with:)` operator enables replacement of `nil` values in a stream
    /// with a substitute value. In the example below, a collection publisher contains
    /// a `nil` value. The `replaceNil(with:)` operator replaces this with `0.0`.
    ///
    ///     let numbers: [Double?] = [1.0, 2.0, nil, 3.0]
    ///     numbers.publisher
    ///         .replaceNil(with: 0.0)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "Optional(1.0) Optional(2.0) Optional(0.0) Optional(3.0)"
    ///
    /// - Parameter output: The element to use when replacing `nil`.
    /// - Returns: A publisher that replaces `nil` elements from the upstream publisher
    ///   with the provided element.
    public func replaceNil<ElementOfResult>(
        with output: ElementOfResult
    ) -> Publishers.Map<Self, ElementOfResult>
        where Output == ElementOfResult?
    {
        // 直接使用 Map.
        return Publishers.Map(upstream: self) { $0 ?? output }
    }
}

extension Publishers {
    /// A publisher that transforms all elements from the upstream publisher with
    /// a provided closure.
    public struct Map<Upstream: Publisher, Output>: Publisher {

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that transforms elements from the upstream publisher.
        public let transform: (Upstream.Output) -> Output

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) -> Output) {
            self.upstream = upstream
            self.transform = transform
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Downstream.Failure == Upstream.Failure
        {
            // 只有的 receive(subscriber 的时候, 才真正的使用 Inner 生成 Subscription 对象.
            upstream.subscribe(Inner(downstream: subscriber, map: transform))
        }
    }

    /// A publisher that transforms all elements from the upstream publisher
    /// with a provided error-throwing closure.
    public struct TryMap<Upstream: Publisher, Output>: Publisher {

        // 经历过 TryMap, 其实是 Error 的类型丢失为最原始的 Error 了.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that transforms elements from
        /// the upstream publisher.
        public let transform: (Upstream.Output) throws -> Output

        public init(upstream: Upstream,
                    transform: @escaping (Upstream.Output) throws -> Output) {
            self.upstream = upstream
            self.transform = transform
        }
    }
}

extension Publishers.Map {

    public func map<Result>(
        _ transform: @escaping (Output) -> Result
    ) -> Publishers.Map<Upstream, Result> {
        return .init(upstream: upstream) { transform(self.transform($0)) }
    }

    public func tryMap<Result>(
        _ transform: @escaping (Output) throws -> Result
    ) -> Publishers.TryMap<Upstream, Result> {
        return .init(upstream: upstream) { try transform(self.transform($0)) }
    }
}

extension Publishers.TryMap {

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Downstream.Failure == Error
    {
        upstream.subscribe(Inner(downstream: subscriber, map: transform))
    }

    public func map<Result>(
        _ transform: @escaping (Output) -> Result
    ) -> Publishers.TryMap<Upstream, Result> {
        return .init(upstream: upstream) { try transform(self.transform($0)) }
    }

    public func tryMap<Result>(
        _ transform: @escaping (Output) throws -> Result
    ) -> Publishers.TryMap<Upstream, Result> {
        // 这里为什么不是两个 try.
        return .init(upstream: upstream) { try transform(self.transform($0)) }
    }
}

extension Publishers.Map {

    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let map: (Input) -> Output

        let combineIdentifier = CombineIdentifier()

        fileprivate init(downstream: Downstream, map: @escaping (Input) -> Output) {
            self.downstream = downstream
            self.map = map
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        // Map 只会在 receive(_ input: Input) 使用 闭包进行数据的转化, 其他的都是透传.
        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(map(input))
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        var description: String { return "Map" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryMap {

    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Error
    {
        // NOTE: This class has been audited for thread-safety

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private let map: (Input) throws -> Output

        private var status = SubscriptionStatus.awaitingSubscription

        private let lock = UnfairLock.allocate()

        let combineIdentifier = CombineIdentifier()

        fileprivate init(downstream: Downstream,
                         map: @escaping (Input) throws -> Output) {
            self.downstream = downstream
            self.map = map
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
                return try downstream.receive(map(input))
            } catch {
                lock.lock()
                let subscription = status.subscription
                status = .terminal
                lock.unlock()
                // 中间节点发生了错误,  通知上游, 通知下游.
                subscription?.cancel()
                downstream.receive(completion: .failure(error))
                return .none
            }
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }

        // 还是透传. 
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

        var description: String { return "TryMap" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
