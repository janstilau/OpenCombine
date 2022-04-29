/*
 添加一个 Operator 有着非常固定的流程.
 1. Protocol 增加定义方法.
 2. 增加一个特殊的对象, 在上述的方法里面, 生成这个特殊的对象.
 3. 确保, 这个特殊的对象, 也符合 Publisher. 这样返回的数据, 可以继续进行 Publisher 对应方法的串联.
 */
extension Publisher {
    
    /// Republishes all elements that match a provided closure.
    
    /// OpenCombine’s `filter(_:)` operator performs an operation similar to that of
    /// `filter(_:)` in the Swift Standard Library: it uses a closure to test each element
    /// to determine whether to republish the element to the downstream subscriber.
    
    /// The following example, uses a filter operation that receives an `Int` and only
    /// republishes a value if it’s even.
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 5]
    ///     cancellable = numbers.publisher
    ///         .filter { $0 % 2 == 0 }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "2 4"
    // 在 Combine 的世界里面, Try 这个单词, 有着很强的暗示, 就是后续可能会引起问题.
    // 所以, 在使用的时候, 不使用 Try 的地方, 一定是不用考虑 error 的. 这是一个好的设计
    
    /// - Parameter isIncluded: A closure that takes one element and returns
    ///   a Boolean value indicating whether to republish the element.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    
    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Self> {
        // 生成一个 Publisher 对象.
        return Publishers.Filter(upstream: self, isIncluded: isIncluded)
    }
    
    /// Republishes all elements that match a provided error-throwing closure.
    ///
    /// Use `tryFilter(_:)` to filter elements evaluated in an error-throwing closure.
    /// If the `isIncluded` closure throws an error, the publisher fails with that error.
    ///
    /// In the example below, `tryFilter(_:)` checks to see if the divisor provided by
    /// the publisher is zero, and throws a `DivisionByZeroError` and then terminates
    /// the publisher with the thrown error:
    ///
    ///     struct DivisionByZeroError: Error {}
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 0, 5]
    ///     cancellable = numbers.publisher
    ///         .tryFilter {
    ///             if $0 == 0 {
    ///                 throw DivisionByZeroError()
    ///             } else {
    ///                 return $0 % 2 == 0
    ///             }
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("\($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "2 4 failure(DivisionByZeroError())".
    ///
    /// - Parameter isIncluded: A closure that takes one element and returns a Boolean
    ///   value that indicated whether to republish the element or throws an error.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Self> {
        return Publishers.TryFilter(upstream: self, isIncluded: isIncluded)
    }
}

extension Publishers.Filter {
    
    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Upstream> {
        return .init(upstream: upstream) { self.isIncluded($0) && isIncluded($0) }
    }
    
    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers.TryFilter {
    
    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
    
    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers {
    
    /// A publisher that republishes all elements that match a provided closure.
    public struct Filter<Upstream: Publisher>: Publisher {
        
        // 固定格式, Fitler 没有改变上游的 Output, 它仅仅是进行过滤
        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output
        
        // 固定格式, Fitler 没有改变上游的 Failure, 它仅仅是进行过滤
        /// The kind of errors this publisher might publish.
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure
        
        // 固定数据, Publisher 要记录上游 Publisher, 这样才能建立起响应链条.
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        // 核心的业务代码, 就是在上游节点发送数据过来之后, 根据该值进行过滤.
        // 注意命名, Block 对象, 就根据业务来命名, 没有 Action, CallBack, Block 这种结尾.
        /// A closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) -> Bool
        
        public init(upstream: Upstream, isIncluded: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
        }
        
        // 固定写法, 生成 Filter 内部的 Subscription 对象, 然后调用上游的注册.
        // 完成响应者链条的搭建.
        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: isIncluded))
        }
    }
    
    /// A publisher that republishes all elements that match
    /// a provided error-throwing closure.
    public struct TryFilter<Upstream>: Publisher where Upstream: Publisher {
        
        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output
        
        // 对于 Try 这种, Failure 就不是一个具体的类型了.
        // 因为, Closure 的错误, 和上游的错误, 是没有办法用一种类型融合的.
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// A error-throwing closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) throws -> Bool
        
        public init(upstream: Upstream,
                    isIncluded: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
        }
        
        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Output == Downstream.Input,
              Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: isIncluded))
        }
    }
}

extension Publishers.Filter {
    
    // Filter 真正的在响应链中的节点.
    // 不需要作为 Subscription, 因为, 直接把 Subscription 交给了下游, 所以下游节点可以直接和上游节点交互.
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        // 固定写法, Sink 节点, 应该记录下游节点.
        // 在完成自己的业务之后, 要把数据传递给下游节点.
        private let downstream: Downstream
        // 业务相关数据, 从 Producer 中拷贝过来.
        private let filter: (Input) -> Bool
        
        let combineIdentifier = CombineIdentifier()
        
        init(downstream: Downstream, filter: @escaping (Input) -> Bool) {
            self.downstream = downstream
            self.filter = filter
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        // 核心, 就是在收到上级节点之后, 进行了 filter 的相关逻辑.
        // 如果真的 Filter 了, 就再要一个. 
        func receive(_ input: Input) -> Subscribers.Demand {
            if filter(input) {
                return downstream.receive(input)
            }
            return .max(1)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
        
        var description: String { return "Filter" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryFilter {
    // 子类中进行了类型的绑定, 这是泛型类使用的非常常见的方式 .
    private final class Inner<Downstream: Subscriber>
    : FilterProducer<Downstream,
      Upstream.Output,
      Upstream.Output,
      Upstream.Failure,
      (Upstream.Output) throws -> Bool>
    where Downstream.Input == Upstream.Output, Downstream.Failure == Error
    {
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Upstream.Output?, Error> {
            do {
                // 没有发生错误, 没过滤掉, 发送给后方, 过滤掉了, 后方什么都不知道.
                // 然后管理 demand.
                return try filter(newValue) ? .continue(newValue) : .continue(nil)
            } catch {
                return .failure(error)
            }
        }
        
        override var description: String { return "TryFilter" }
    }
}
