extension Publisher {
    /// Transforms all elements from the upstream publisher with a provided closure.
    
    /// OpenCombine’s `map(_:)` operator performs a function similar to that of `map(_:)`
    /// in the Swift standard library: it uses a closure to transform each element it
    /// receives from the upstream publisher. You use `map(_:)` to transform from one kind
    /// of element to another.
    
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
    
    /// - Parameter transform: A closure that takes one element as its parameter and
    ///   returns a new element.
    /// - Returns: A publisher that uses the provided closure to map elements from
    ///   the upstream publisher to new elements that it then publishes.
    
    // Combine 中, 将 Transform 和 TryTransform 进行了区分, 是一个非常好的设计.
    public func map<Result>(
        _ transform: @escaping (Output) -> Result
    ) -> Publishers.Map<Self, Result> {
        return Publishers.Map(upstream: self, transform: transform)
    }
    
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
    // 使用闭包, 有着很强的灵活性.
    // ReplaceNil 其实还是使用 map 的逻辑, 只不过修改了 transform 的逻辑.
    public func replaceNil<ElementOfResult>(
        with output: ElementOfResult
    ) -> Publishers.Map<Self, ElementOfResult>
    where Output == ElementOfResult?
    {
        return Publishers.Map(upstream: self) { $0 ?? output }
    }
}

extension Publishers {
    /// A publisher that transforms all elements from the upstream publisher with
    /// a provided closure.
    
    public struct Map<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        // 这种可以直接当成员变量啊.
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
            upstream.subscribe(Inner(downstream: subscriber, map: transform))
        }
    }
    
    /// A publisher that transforms all elements from the upstream publisher
    /// with a provided error-throwing closure.
    public struct TryMap<Upstream: Publisher, Output>: Publisher {
        
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

// 融合的过程.
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
        // 生成一个 Inner 节点, 作为上级的 receiver, 继续构建前面的节点.
        // 在自己的 Inner 节点中, 将 downstream 和自己进行了串联.
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
        return .init(upstream: upstream) { try transform(self.transform($0)) }
    }
}

extension Publishers.Map {
    
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output,
          Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        // Map 的 Inner 节点, 作为响应联调的一环, 强引用了下游节点.
        private let downstream: Downstream
        
        // Map 真正的 Transform 的引用.
        private let map: (Input) -> Output
        
        let combineIdentifier = CombineIdentifier()
        
        fileprivate init(downstream: Downstream, map: @escaping (Input) -> Output) {
            self.downstream = downstream
            self.map = map
        }
        
        // 这个函数, 是上游节点主动调用的.
        // Map 直接交给了下游.
        // 在 Map 里面, 是没有 Demand 的管理的.
        
        // 直接, 把上游的 Subscription 交给了下游, 所以下游调用 request, 也是直接使用上游的 Request 方法.
        // 这里, 没有 Map 的 Inner 节点的循环引用. 它完全依赖于这个响应者链条.
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        // Map 没有错误处理, 直接 forward.
        func receive(_ input: Input) -> Subscribers.Demand {
            // 作为中间件, Map 的责任就是进行 transform, 然后调用下游的 receive 将数据进行传递.
            return downstream.receive(map(input))
        }
        
        // Map 没有错误处理, 直接 forward.
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
    
    // TryMap, 是要实现 Subscription 的.
    // 他要实现 Demand 的管理, 要实现 cancel 的逻辑.
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
        
        // 对下游节点, 进行强引用.
        private let downstream: Downstream
        
        // 对于可能出错的转化函数, 进行强引用.
        private let map: (Input) throws -> Output
        
        // 对于上游节点, 进行强引用.
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
        
        /*
         构建, 响应响应者链条, 是生成各个 Publisher 的 Inner 节点.
         在这个过程中, 各个 Inner 节点, 作为 downstream 添加到上游节点的 next 中.
         
         在最后, 起始节点的 Inner 对象, 会把自身作为 Subscription, 调用下级节点的 func receive(subscription: Subscription)
         下游节点:
         1. 强引用上游节点. 形成循环引用.
         2. 可能调用 Subscription 的 request 方法.
         3. 将自身, 作为下游节点的 Subscription, 再次调用下游节点的 request.
         
         如果, 自己本身只是一个中间 forward 节点. 那么 Inner 实现 Subscription 的功能, 来实现
         func request(_ demand: Subscribers.Demand) 方法.
         forward 节点的 request(_ demand: Subscribers.Demand) 实现, 也就是转交给存储的 Subscription, 调用对应的 request.
         
         整个的响应链路构建过程, 是从后向前的.
         整个的 Subscription 传递过程, 是从前向后的.
         然后整个 Subscriber 的 request Demand 的过程, 是从后向前的.
         
         真正的信号产生, 是在 request Demand 的方法内部.
         
         相比较 rx, 其实只有一个 subscribe 方法, 是响应链路的构建过程. 在最前方的节点, 被构建出来之后, 其实也就执行了信号触发的逻辑了.
         */
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 对于上游节点, 进行强引用.
            status = .subscribed(subscription)
            lock.unlock()
            
            // 然后自己作为节点, 传递给后方节点.
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
                // 当, 一个节点发现整个处理链条应该结束了之后, 要做两件事.
                // 1. 上游节点的 cancel 操作. 一般来说, 存储的 subscription 对象, 就是上游节点对象
                // 2. 下游节点的 completion 的发送.
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
            // 收到了完成事件, 只会在上游节点, 已经完成了 cancel 操作的情况下才会执行.
            // 所以, 这里不会触发上游节点的 cancel 操作.
            // 在完成了自己的资源释放之后, 触发下游节点的 completion 事件的接收.
            status = .terminal
            lock.unlock()
            downstream.receive(completion: completion.eraseError())
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            
            // TryMap 并没有 demand 管理的职责, 向上抛出去.
            // 应该说, 对于大部分的 Operator 来说, 都没有 Demand 管理的能力, 只能是顺着线路, 将 Demand 管理往上抛出.
            // 应该只有那些, 真正能生产出信号的 Publisher 产生的节点, 才能有 Demand 管理的能力.
            subscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            // 上游节点的强引用消除.
            status = .terminal
            lock.unlock()
            // 调用上游节点的 cancel.
            subscription.cancel()
        }
        
        var description: String { return "TryMap" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}
