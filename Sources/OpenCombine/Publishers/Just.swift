
/// A publisher that emits an output to each subscriber just once, and then finishes.
///
/// You can use a `Just` publisher to start a chain of publishers.
///  A `Just` publisher is also useful when replacing a value with `Publishers.Catch`.
// 这里说的很明显了, Just 就可以当做单值进行处理.

/// In contrast with `Result.Publisher`, a `Just` publisher can’t fail with an error.
/// And unlike `Optional.Publisher`, a `Just` publisher always produces a value.

public struct Just<Output>: Publisher {
    
    public typealias Failure = Never // 不会有错误.
    
    /// The one element that the publisher emits.
    public let output: Output
    
    /// Initializes a publisher that emits the specified output just once.
    ///
    /// - Parameter output: The one element that the publisher emits.
    public init(_ output: Output) {
        self.output = output
    }
    
    // 同惯例一样, 在 receive(subscriber 中, 生成了这个 Operator 对应的节点对象, 然后交给下游, 当做是 Subscription 来进行使用.
    // 因为, Just 一般就是响应链路的头结点, 所以, 在生成 Inner 的过程中, 不会有 upstream 相关的逻辑.
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Never
    {
        subscriber.receive(subscription: Inner(value: output, downstream: subscriber))
    }
}

extension Just: Equatable where Output: Equatable {}

extension Just where Output: Comparable {
    
    public func min() -> Just<Output> {
        return self
    }
    
    public func max() -> Just<Output> {
        return self
    }
}

extension Just where Output: Equatable {
    
    public func contains(_ output: Output) -> Just<Bool> {
        return .init(self.output == output)
    }
    
    public func removeDuplicates() -> Just<Output> {
        return self
    }
}

extension Just {
    public func allSatisfy(_ predicate: (Output) -> Bool) -> Just<Bool> {
        return .init(predicate(output))
    }
    
    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try predicate(output) })
    }
    
    public func contains(where predicate: (Output) -> Bool) -> Just<Bool> {
        return .init(predicate(output))
    }
    
    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try predicate(output) })
    }
    
    public func collect() -> Just<[Output]> {
        return .init([output])
    }
    
    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }
    
    public func max(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }
    
    public func count() -> Just<Int> {
        return .init(1)
    }
    
    public func dropFirst(_ count: Int = 1) -> Optional<Output>.OCombine.Publisher {
        precondition(count >= 0, "count must not be negative")
        return .init(count > 0 ? nil : self.output)
    }
    
    public func drop(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? nil : output)
    }
    
    public func first() -> Just<Output> {
        return self
    }
    
    public func first(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }
    
    public func last() -> Just<Output> {
        return self
    }
    
    public func last(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }
    
    public func ignoreOutput() -> Empty<Output, Never> {
        return .init()
    }
    
    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Just<ElementOfResult> {
        return .init(transform(output))
    }
    
    public func tryMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(Result { try transform(output) })
    }
    
    public func compactMap<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult?
    ) -> Optional<ElementOfResult>.OCombine.Publisher {
        return .init(transform(output))
    }
    
    public func filter(
        _ isIncluded: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(isIncluded(output) ? output : nil)
    }
    
    public func output(at index: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(index >= 0, "index must not be negative")
        return .init(index == 0 ? output : nil)
    }
    
    public func output<RangeExpression: Swift.RangeExpression>(
        in range: RangeExpression
    ) -> Optional<Output>.OCombine.Publisher where RangeExpression.Bound == Int {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        let range = range.relative(to: 0..<Int.max)
        return .init(range.lowerBound == 0 ? output : nil)
        // The above implementation is used for compatibility.
        //
        // It actually probably should be just this:
        // return .init(range.contains(0) ? output : nil)
    }
    
    public func prefix(_ maxLength: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(maxLength >= 0, "maxLength must not be negative")
        return .init(maxLength > 0 ? output : nil)
    }
    
    public func prefix(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }
    
    public func setFailureType<Failure: Error>(
        to failureType: Failure.Type
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return .init(output)
    }
    
    public func mapError<Failure: Error>(
        _ transform: (Never) -> Failure
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return .init(output)
    }
    
    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }
    
    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Result<Output, Error>.OCombine.Publisher {
        return .init(Result { try _ = predicate(output, output); return output })
    }
    
    public func replaceError(with output: Output) -> Just<Output> {
        return self
    }
    
    public func replaceEmpty(with output: Output) -> Just<Output> {
        return self
    }
    
    public func retry(_ times: Int) -> Just<Output> {
        return self
    }
    
    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Result<Accumulator, Never>.OCombine.Publisher {
        return .init(nextPartialResult(initialResult, output))
    }
    
    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) throws -> Accumulator
    ) -> Result<Accumulator, Error>.OCombine.Publisher {
        return .init(Result { try nextPartialResult(initialResult, output) })
    }
    
    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Result<ElementOfResult, Never>.OCombine.Publisher {
        return .init(nextPartialResult(initialResult, output))
    }
    
    public func tryScan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(Result { try nextPartialResult(initialResult, output) })
    }
    
    public func prepend(_ elements: Output...) -> Publishers.Sequence<[Output], Never> {
        return prepend(elements)
    }
    
    public func prepend<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Sequence<[Output], Never> where Output == Elements.Element {
        return .init(sequence: elements + [output])
    }
    
    public func append(_ elements: Output...) -> Publishers.Sequence<[Output], Never> {
        return append(elements)
    }
    
    public func append<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Sequence<[Output], Never> where Output == Elements.Element {
        return .init(sequence: [output] + elements)
    }
}

extension Just {
    // 因为, just 一定是头结点, 所以不会作为 Subscriber 存在. 不会承担上游的数据
    // 因为, Just 是其他节点的上游节点, 所以要成为 Subscription, 接受下游节点的 Demand 请求, 和 cancel 操作.
    private final class Inner<Downstream: Subscriber>
    : Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output
    {
        // 记录下游节点
        private var downstream: Downstream?
        // 记录自己要发送的数据.
        private let value: Output
        
        fileprivate init(value: Output, downstream: Downstream) {
            self.downstream = downstream
            self.value = value
        }
        
        // 当, 下游节点, 调用上游节点, 也就是他接收到的 Subscription 的 Request Demand 的时候, 才会真正的触发上游节点的信号发送的工作.
        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            guard let downstream = self.downstream.take() else { return }
            
            // 真正的, 进行下游节点接受数据的操作.
            _ = downstream.receive(value)
            // Just 的业务含义, 就是
            downstream.receive(completion: .finished)
        }
        
        // cancel 就是解开下游节点的引用.
        func cancel() {
            downstream = nil
        }
        
        var description: String { return "Just" }
        
        var customMirror: Mirror {
            return Mirror(self, unlabeledChildren: CollectionOfOne(value))
        }
        
        var playgroundDescription: Any { return description }
    }
}
