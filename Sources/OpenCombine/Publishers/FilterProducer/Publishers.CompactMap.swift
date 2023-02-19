
extension Publisher {
    
    /// Calls a closure with each received element and publishes any returned optional
    /// that has a value.
    
    /// OpenCombine’s `compactMap(_:)` operator performs a function similar to that of
    /// `compactMap(_:)` in the Swift standard library: the `compactMap(_:)` operator in
    /// OpenCombine removes `nil` elements in a publisher’s stream and republishes
    /// non-`nil` elements to the downstream subscriber.
    
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
    
    /// - Parameter transform: A closure that receives a value and returns an optional
    ///   value.
    /// - Returns: Any non-`nil` optional results of the calling the supplied closure.
    
    // 泛型, 接收到上游节点的输出, 然后产生自己的输出. 这个产生的过程, 有可能失败.
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
    public func tryCompactMap<ElementOfResult>(
        _ transform: @escaping (Output) throws -> ElementOfResult?
    ) -> Publishers.TryCompactMap<Self, ElementOfResult> {
        return .init(upstream: self, transform: transform)
    }
}

/*
 这里, 专门为 CompactMap 增加 compactMap, map 的适配, 主要是为了减少节点的生成次数.
 使用 { self.transform($0).flatMap(transform) } 对闭包进行了融合.
 这样, 两个 compactMap.compactMap 只会有一个节点生成. 
 */
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
    /// A publisher that republishes all non-`nil` results of calling a closure with each received element.
    
    public struct CompactMap<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        // 惯例, Producer 要记录上游节点的 Producer.
        public let upstream: Upstream
        
        /// A closure that receives values from the upstream publisher and returns optional values.
        // 存储 Producer 的业务相关数据.
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
    // CompactMap 的真正 Inner 节点.
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        // 将, 下游节点, 业务闭包, 全部从 Producer 中复制过来.
        private let downstream: Downstream
        private let filter: (Input) -> Downstream.Input?
        
        let combineIdentifier = CombineIdentifier()
        
        init(downstream: Downstream, filter: @escaping (Input) -> Downstream.Input?) {
            self.downstream = downstream
            self.filter = filter
        }
        
        // 惯例, 不会产生错误的节点, 直接把上游节点传递给下游节点, 当做下游节点的 Subscription
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        // 接收到了上游节点, filter 处理完之后, 交给下游节点. 这也是 Map 的主要存在的价值.
        func receive(_ input: Input) -> Subscribers.Demand {
            // 只有, 返回的数据不是 nil 的情况下, 才将数据发送给后面. 
            if let output = filter(input) {
                return downstream.receive(output)
            }
            // 过滤掉了, 向上游再要一个.
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
    // TryCompactMap 的 Inner 节点, 是一个 FilterProducer
    private final class Inner<Downstream: Subscriber>
    : FilterProducer<Downstream,
      Upstream.Output,
      Output,
      Upstream.Failure,
      (Upstream.Output) throws -> Output?>
    where Downstream.Failure == Error, Downstream.Input == Output
    {
        // 自定义了 receive( newValue 的逻辑.
        override func receive(
            newValue: Upstream.Output
        ) -> ReceiveValueCompletion<Output?, Error> {
            do {
                return try .continue(valueJudgement(newValue))
            } catch {
                return .failure(error)
            }
        }
        
        override var description: String { return "TryCompactMap" }
    }
}
