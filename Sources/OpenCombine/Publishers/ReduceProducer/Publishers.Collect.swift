// 就是收集所有的 Ele, 然后当做一个数组一次性的发射出来给后面的节点.
extension Publisher {
    /// Collects all received elements, and emits a single array of the collection when
    /// the upstream publisher finishes.
    
    /// Use `collect()` to gather elements into an array that the operator emits after
    /// the upstream publisher finishes.
    
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    
    /// This publisher requests an unlimited number of elements from the upstream
    /// publisher and uses an unbounded amount of memory to store the received values.
    /// The publisher may exert memory pressure on the system for very large sets of
    /// elements.
    // 这里说明, 在 OpenCombine 的逻辑里面, 是无限制的进行缓存的.
    
    /// The `collect()` operator only sends the collected array to its downstream receiver
    /// after a request whose demand is greater than 0 items. Otherwise, `collect()` waits
    /// until it receives a non-zero request.
    
    // 因为, Combine 的 Pull 模型, 所以条件是 1. 上游 finish 了. 2. 下游 request 了.
    
    /// In the example below, an Integer range is a publisher that emits an array of
    /// integers:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .collect()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// - Returns: A publisher that collects all received items and returns them as
    ///   an array upon completion.
    public func collect() -> Publishers.Collect<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {
    
    // 一个惯例的实现. 因为要发送 value 数据, 所以要生成一个 Inner 节点, 来完成 Subscription 的实现.
    public struct Collect<Upstream: Publisher>: Publisher {
        
        public typealias Output = [Upstream.Output]
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream
        
        public init(upstream: Upstream) {
            self.upstream = upstream
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Downstream.Input == [Upstream.Output]
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }
}

extension Publishers.Collect: Equatable where Upstream: Equatable {}

extension Publishers.Collect {
    private final class Inner<Downstream: Subscriber>
    : ReduceProducer<Downstream,
      Upstream.Output,
      [Upstream.Output], // 在这里, 指明了 Result 的类型是什么.
      Upstream.Failure,
    // 在这里指明了, Filter 的类型是什么.
      Void>
    where Downstream.Input == [Upstream.Output],
          Downstream.Failure == Upstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            // Reduce 的类型是 Void, 但是它是一个值啊, 必须要传递一个值过去才行.
            super.init(downstream: downstream, initial: [], reduce: ())
        }
        
        // 主要的实现逻辑, 还是 ReduceProducer 完成.
        // Result 的更新逻辑, 就是不断的拼接到 Result 中.
        override func receive(
            newValue: Upstream.Output
        ) -> ReceiveValueCompletion<Void, Downstream.Failure> {
            // ReduceProducer 的子类, 指定了 Result 的类型是 []了.
            // 这里没有使用 filter 的逻辑. 
            result!.append(newValue)
            return .continue
        }
        
        override var description: String {
            return "Collect"
        }
        
        override var customMirror: Mirror {
            let children: CollectionOfOne<Mirror.Child> = .init(("count", result!.count))
            return Mirror(self, children: children)
        }
    }
}
