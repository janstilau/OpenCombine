
extension Publisher where Output: Equatable {
    
    /// Publishes a Boolean value upon receiving an element equal to the argument.
    
    /// Use `contains(_:)` to find the first element in an upstream that’s equal to
    /// the supplied argument. The `Publishers.Contains` publisher consumes all received
    /// elements until the upstream publisher produces a matching element.
    
    /// Upon finding the first match, it emits `true` and finishes normally. If the upstream finishes
    /// normally without producing a matching element, this publisher emits `false` and
    /// finishes.
    // 当, 发现了第一个之后, 会 emit true, 这算是一个剪枝操作.
    // 如果直到最后, 都是 false, 那么才会发射 false. 所以, 其实是依赖上游节点的 Completion 事件的.
    
    // consumes all received elements until the upstream publisher produces a matching element
    // 正是因为如此, Contains 在做 Demand 管理的时候, 向上游节点, 是使用 unlimited . 它本身就是需要消耗大量的上游节点, 才能完成的操作.
    
    /// In the example below, the `contains(_:)` operator emits `true` the first time it
    /// receives the value `5` from the `numbers.publisher`, and then finishes normally.
    ///
    ///     let numbers = [-1, 5, 10, 5]
    ///     numbers.publisher
    ///         .contains(5)
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "true"

    /// - Parameter output: An element to match against.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    
    public func contains(_ output: Output) -> Publishers.Contains<Self> {
        return .init(upstream: self, output: output)
    }
}

extension Publisher {
    
    /// Publishes a Boolean value upon receiving an element that satisfies the predicate
    /// closure.
    
    /// Use `contains(where:)` to find the first element in an upstream that satisfies
    /// the closure you provide. This operator consumes elements produced from
    /// the upstream publisher until the upstream publisher produces a matching element.
    
    /// This operator is useful when the upstream publisher produces elements that don’t
    /// conform to `Equatable`.
    ///
    /// In the example below, the `contains(where:)` operator tests elements against
    /// the supplied closure and emits `true` for the first elements that’s greater than
    /// `4`, and then finishes normally.
    ///
    ///     let numbers = [-1, 0, 10, 5]
    ///     numbers.publisher
    ///         .contains {$0 > 4}
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "true"
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value that indicates whether the element satisfies
    ///   the closure’s comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    public func contains(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.ContainsWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
    
    // TryPredicate, 里面可能会抛出错误. 在对应的 Inner 节点中, 增加了错误处理的相关代码.
    /// Publishes a Boolean value upon receiving an element that satisfies the throwing
    /// predicate closure.
    
    /// Use `tryContains(where:)` to find the first element in an upstream that satisfies
    /// the error-throwing closure you provide.
    ///
    /// This operator consumes elements produced from the upstream publisher until
    /// the upstream publisher either:
    
    /// - Produces a matching element, after which it emits `true` and the publisher
    ///   finishes normally.
    /// - Emits `false` if no matching element is found and the publisher finishes
    ///   normally.
    
    // 如果, predicate 中出错了, 那么产生的错误, 会顺着向下传下去.
    /// If the predicate throws an error, the publisher fails, passing the error to its
    /// downstream.
    
    
    /// In the example below, the `tryContains(where:)` operator tests values to find
    /// an element less than `10`; when the closure finds an odd number, like `3`,
    /// the publisher terminates with an `IllegalValueError`.
    ///
    ///     struct IllegalValueError: Error {}
    ///
    ///     let numbers = [3, 2, 10, 5, 0, 9]
    ///     numbers.publisher
    ///         .tryContains {
    ///             if ($0 % 2 != 0) {
    ///                 throw IllegalValueError()
    ///             }
    ///            return $0 < 10
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") },
    ///             receiveValue: { print ("value: \($0)") }
    ///         )
    ///
    ///     // Prints: "completion: failure(IllegalValueError())"
    ///
    /// - Parameter predicate: A closure that takes an element as its parameter and
    ///   returns a Boolean value that indicates whether the element satisfies
    ///   the closure’s comparison logic.
    /// - Returns: A publisher that emits the Boolean value `true` when the upstream
    ///   publisher emits a matching value.
    public func tryContains(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryContainsWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {
    
    /// A publisher that emits a Boolean value when a specified element is received from
    /// its upstream publisher.
    // 真正的 Producer 类. 按照管理, 存储信息, 以及相应链条所需要的东西.
    public struct Contains<Upstream: Publisher>: Publisher
    where Upstream.Output: Equatable {
        
        public typealias Output = Bool
        
        public typealias Failure = Upstream.Failure
        
        // The publisher from which this publisher receives elements.
        // 按照惯例, Producer 里面, 存储上游节点的 Publisher. 注意, 不是真正存储上游节点, 而是存储上游节点的生成器
        public let upstream: Upstream
        
        /// The element to scan for in the upstream publisher.
        public let output: Upstream.Output
        
        public init(upstream: Upstream, output: Upstream.Output) {
            self.upstream = upstream
            self.output = output
        }
        
        // 惯例, 当收到新的 Subscriber 的时候, 生成真正的节点, 然后, attach 到上游.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, output: output))
        }
    }
    
    /// A publisher that emits a Boolean value upon receiving an element that satisfies
    /// the predicate closure.
    // 和上面的 struct Contains 没有任何的区别. 只不过存储的多了一个 Predicate 闭包, 生成真正节点的时候, 是对应的数据类型.
    public struct ContainsWhere<Upstream: Publisher>: Publisher {
        public typealias Output = Bool
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The closure that determines whether the publisher should consider an element as a match.
        public let predicate: (Upstream.Output) -> Bool
        
        // 惯例, Producer 主要工作, 是收集各种业务相关数据.
        public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }
        
        // 惯例, Producer 在收到下游节点的时候, 构建自己的业务节点, 然后触发上游节点的创建工作.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
    
    /// A publisher that emits a Boolean value upon receiving an element that satisfies
    /// the throwing predicate closure.
    public struct TryContainsWhere<Upstream: Publisher>: Publisher {
        
        public typealias Output = Bool
        
        public typealias Failure = Error
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The error-throwing closure that determines whether this publisher should
        /// emit a `true` element.
        public let predicate: (Upstream.Output) throws -> Bool
        
        public init(upstream: Upstream,
                    predicate: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Error, Downstream.Input == Bool
        {
            upstream.subscribe(Inner(downstream: subscriber, predicate: predicate))
        }
    }
}


// ~~~~~~~~~~~~~~~ 节点 ~~~~~~~~~~~~~~~~~

extension Publishers.Contains {
    // Contains 的相关的节点.
    private final class Inner<Downstream: Subscriber>
    : ReduceProducer<Downstream, Upstream.Output, Bool, Upstream.Failure, Void>
    where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
    {
        private let output: Upstream.Output
        
        // 惯例, 节点要把生成器中的数据复制过来.
        fileprivate init(downstream: Downstream, output: Upstream.Output) {
            self.output = output
            super.init(downstream: downstream, initial: false, reduce: ())
        }
        
        // Publishers.Contains 中, Predicate 的相关逻辑, 就是 == 进行比较.
        // 依赖于 Equatable 的协议限制.
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if newValue == output {
                result = true
                return .finished
            }
            
            return .continue
        }
        
        override var description: String { return "Contains" }
    }
}

extension Publishers.Contains : Equatable where Upstream: Equatable {}

extension Publishers.ContainsWhere {
    private final class Inner<Downstream: Subscriber>
    : ReduceProducer<Downstream,
      Upstream.Output, Bool,
      Upstream.Failure,
      (Upstream.Output) -> Bool>
    where Upstream.Failure == Downstream.Failure, Downstream.Input == Bool
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) -> Bool) {
            super.init(downstream: downstream, initial: false, reduce: predicate)
        }
        
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            // 明确的使用闭包, 来做判断.
            if reduce(newValue) {
                result = true
                return .finished
            }
            
            return .continue
        }
        
        override var description: String { return "ContainsWhere" }
    }
}

extension Publishers.TryContainsWhere {
    private final class Inner<Downstream: Subscriber>
    : ReduceProducer<Downstream,
      Upstream.Output, Bool,
      Upstream.Failure,
      (Upstream.Output) throws -> Bool>
    where Downstream.Failure == Error, Downstream.Input == Bool
    {
        fileprivate init(downstream: Downstream,
                         predicate: @escaping (Upstream.Output) throws -> Bool) {
            super.init(downstream: downstream, initial: false, reduce: predicate)
        }
        
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            // 明确的使用闭包来做判断, 但是有可能会出错.
            do {
                if try reduce(newValue) {
                    result = true
                    return .finished
                }
            } catch {
                return .failure(error)
            }
            
            return .continue
        }
        
        override var description: String { return "TryContainsWhere" }
    }
}
