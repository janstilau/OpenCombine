/*
 定义一个新的 Operator, 定义对应的Publisher
 
 Publisher 用来做信息收集的, 收集业务所需要的参数, 收集 Upstream Publisher
 
 定义对应的 Subscription
 
 Subscription 是真正的响应链条中的节点. 他要是 Subscriber, 用来处理上游的信息.
 他要是一个 Subscription, 用来处理下游的 Demand 管理, 以及下游的 Cancel 请求.
 
 要定义一个 Publsiher 的方法, 在该方法的内部, 进行 Publisher 初始化, 完成收集信息的工作.
 要实现 Publsiher 的 Receive 方法, 完成 Subscription 的生成, 触发整个响应链路的搭建.
 */
extension Publisher {
    /// Shares the output of an upstream publisher with multiple subscribers.
    // 实现的方式是, 将一个 Subject 作为 Upstream 的终点.
    // 后面的 Subscriber 作为 Subject 所管理的下游节点, 挂钩到 Subject 之上.
    
    /// The publisher returned by this operator supports multiple subscribers, all of whom
    /// receive unchanged elements and completion states from the upstream publisher.
    
    ///  - Tip: `Publishers.Share` is effectively a combination of
    ///  the `Publishers.Multicast` and `PassthroughSubject` publishers, with an implicit
    ///  `autoconnect()`.
    
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator. It uses a `share()` operator
    /// to share the same random number to each of two subscribers. This example uses
    /// a `delay(for:tolerance:scheduler:options:)` operator only to prevent the first
    /// subscriber from exhausting the sequence publisher immediately; an asynchronous
    /// publisher wouldn’t need this.
    
    // 如果, 没有 Delay, 那么 Stream 1 就会把所有的数据全部消耗完了. 
    ///     let pub = (1...3).publisher
    ///         .delay(for: 1, scheduler: DispatchQueue.main)
    ///         .map( { _ in return Int.random(in: 0...100) } )
    ///         .print("Random")
    ///         .share()
    
    ///     cancellable1 = pub
    ///         .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///         .sink { print ("Stream 2 received: \($0)")}
    
    ///     // Prints:
    ///     // Random: receive value: (20)
    ///     // Stream 1 received: 20
    ///     // Stream 2 received: 20
    ///     // Random: receive value: (85)
    ///     // Stream 1 received: 85
    ///     // Stream 2 received: 85
    ///     // Random: receive value: (98)
    ///     // Stream 1 received: 98
    ///     // Stream 2 received: 98
    ///
    /// Without the `share()` operator, stream 1 receives three random values,
    /// followed by stream 2 receiving three different random values.
    ///
    /// Also note that `Publishers.Share` is a `class` rather than a `struct` like most
    /// other publishers. This means you can use this operator to create a publisher
    /// instance that uses reference semantics.
    ///
    /// - Returns: A class instance that shares elements received from its upstream to
    ///   multiple subscribers.
    public func share() -> Publishers.Share<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {
    
    /// A publisher that shares the output of an upstream publisher with multiple
    /// subscribers.
    ///
    /// This publisher type supports multiple subscribers, all of whom receive unchanged
    /// elements and completion states from the upstream publisher.
    ///
    ///  - Tip: `Publishers.Share` is effectively a combination of
    ///  the `Publishers.Multicast` and `PassthroughSubject` publishers,
    ///  with an implicit `autoconnect()`.
    ///
    /// Also note that `Publishers.Share` is a `class` rather than a `struct` like most
    /// other publishers. Use this type when you need a publisher instance that uses
    /// reference semantics.
    public final class Share<Upstream: Publisher>: Publisher, Equatable {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        private typealias MulticastSubject = PassthroughSubject<Output, Failure>
        
        private let inner: Autoconnect<Multicast<Upstream, MulticastSubject>>
        
        public let upstream: Upstream
        
        // Share 就是一个 自动连接的, Multicast.
        // Multicast 是 Share 最主要的需求, 就是共享前面链路的数据.
        // AutoConnect 是为了不改变之前 Publisher 的行为, 不应该强制进行 connect 的调用.
        public init(upstream: Upstream) {
            // 和惯例的不通过. 这个 Inner 是提前生成的. 这个 Inner 就是一个分发器.
            // 上有节点, 连接到这个 Inner, Inner 连接到后续节点. 
            self.inner = upstream.multicast(subject: .init()).autoconnect()
            self.upstream = upstream
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Failure
        {
            inner.subscribe(subscriber)
        }
        
        public static func == (lhs: Share, rhs: Share) -> Bool {
            return lhs === rhs
        }
    }
}
