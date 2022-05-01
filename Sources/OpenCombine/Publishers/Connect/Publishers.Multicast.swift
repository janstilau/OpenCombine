extension Publisher {
    
    /// Applies a closure to create a subject that delivers elements to subscribers.
    // 真正的能够成为多路复用的响应链, 是因为将后面的链条, 都挂钩到了一个 Subject 对象上了.
    
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    /// This is useful when upstream publishers are doing expensive work you don’t want
    /// to duplicate, like performing network requests.
    
    // 默认是, 每一次 Subscriber 注册, 都是一个响应链条.
    // 为了避免上游节点多次触发产生信号的操作, 添加一个中间节点作为分发节点.
    // 上游节点的信号到达之后, 分发节点后触发各个子链条的处理过程.
    // 内部是通过 Subject 来实现的. 因为, Subject 天然就是一个分发节点.
    
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator.
    /// It uses a `multicast(_:)` operator whose closure creates a `PassthroughSubject`
    /// to share the same random number to each of two subscribers. Because the multicast
    /// publisher is a `ConnectablePublisher`, publishing only begins after a call to
    /// `connect()`.
    ///
    ///     let pub = ["First", "Second", "Third"].publisher
    ///         .map( { return ($0, Int.random(in: 0...100)) } )
    ///         .print("Random")
    ///         .multicast { PassthroughSubject<(String, Int), Never>() }
    ///
    ///     cancellable1 = pub
    ///        .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///        .sink { print ("Stream 2 received: \($0)")}
    
    // 上面的两个 Sink, 是将 Sink生成的节点, Attach 到 PassthroughSubject 的 ConduitList中
    // 只有下面的 connect 调用了之后, 才是将 Subject 对象, 和 Upstream 进行 attach.
    // Subject 是 Unlimited 拉取上游节点的数据. 然后, 在根据各自下游的 Demand 将接收到的数据下发给各个子响应链条.
    
    ///     pub.connect()
    
    ///     // Prints:
    ///     // Random: receive value: (("First", 9))
    ///     // Stream 2 received: ("First", 9)
    ///     // Stream 1 received: ("First", 9)
    ///     // Random: receive value: (("Second", 46))
    ///     // Stream 2 received: ("Second", 46)
    ///     // Stream 1 received: ("Second", 46)
    ///     // Random: receive value: (("Third", 26))
    ///     // Stream 2 received: ("Third", 26)
    ///     // Stream 1 received: ("Third", 26)
    ///
    /// In this example, the output shows that the `print(_:to:)` operator receives each
    /// random value only one time, and then sends the value to both subscribers.
    ///
    /// - Parameter createSubject: A closure to create a new `Subject` each time
    ///   a subscriber attaches to the multicast publisher.
    public func multicast<SubjectType: Subject>(
        _ createSubject: @escaping () -> SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
    where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return Publishers.Multicast(upstream: self, createSubject: createSubject)
    }
    
    /// Provides a subject to deliver elements to multiple subscribers.
    ///
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    /// This is useful when upstream publishers are doing expensive work you don’t want
    /// to duplicate, like performing network requests.
    ///
    /// In contrast with `multicast(_:)`, this method produces a publisher that shares
    /// the provided `Subject` among all the downstream subscribers.
    ///
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator.
    /// It uses a `multicast(subject:)` operator with a `PassthroughSubject` to share
    /// the same random number to each of two subscribers. Because the multicast publisher
    /// is a `ConnectablePublisher`, publishing only begins after a call to `connect()`.
    ///
    ///     let pub = ["First", "Second", "Third"].publisher
    ///         .map( { return ($0, Int.random(in: 0...100)) } )
    ///         .print("Random")
    ///         .multicast(subject: PassthroughSubject<(String, Int), Never>())
    ///
    ///     cancellable1 = pub
    ///         .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///         .sink { print ("Stream 2 received: \($0)")}
    ///     pub.connect()
    ///
    ///     // Prints:
    ///     // Random: receive value: (("First", 78))
    ///     // Stream 2 received: ("First", 78)
    ///     // Stream 1 received: ("First", 78)
    ///     // Random: receive value: (("Second", 98))
    ///     // Stream 2 received: ("Second", 98)
    ///     // Stream 1 received: ("Second", 98)
    ///     // Random: receive value: (("Third", 61))
    ///     // Stream 2 received: ("Third", 61)
    ///     // Stream 1 received: ("Third", 61)
    ///
    /// In this example, the output shows that the `print(_:to:)` operator receives each
    /// random value only one time, and then sends the value to both subscribers.
    
    /// - Parameter subject: A subject to deliver elements to downstream subscribers.
    
    public func multicast<SubjectType: Subject>(
        subject: SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
    where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return multicast { subject }
    }
}

extension Publishers {
    
    /// A publisher that uses a subject to deliver elements to multiple subscribers.
    
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    
    public final class Multicast<Upstream: Publisher, SubjectType: Subject>
    : ConnectablePublisher
    where Upstream.Failure == SubjectType.Failure,
          Upstream.Output == SubjectType.Output
    {
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream
        
        /// A closure to create a new Subject each time a subscriber attaches
        /// to the multicast publisher.
        // 如何去创建分发节点, 是用 Object 这个天然就是可以分发的类型
        public let createSubject: () -> SubjectType
        
        private let lock = UnfairLock.allocate()
        
        private var generatedSubject: SubjectType?
        
        // 懒加载.
        private var lazySubject: SubjectType {
            lock.lock()
            if let subject = generatedSubject {
                lock.unlock()
                return subject
            }
            
            let subject = createSubject()
            self.generatedSubject = subject
            lock.unlock()
            return subject
        }
        
        /// Creates a multicast publisher that applies a closure to create a subject that
        /// delivers elements to subscribers.
        ///
        /// - Parameter createSubject: A closure that returns a `Subject` each time
        ///   a subscriber attaches to the multicast publisher.
        // 对于 Publihser 来说, 在类内的主要逻辑, 就是收集数据.
        public init(upstream: Upstream, createSubject: @escaping () -> SubjectType) {
            self.upstream = upstream
            self.createSubject = createSubject
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 当, 后方节点要 Attach 的时候, 生成 Inner 节点, attach 到 Subject 对象上.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where SubjectType.Failure == Downstream.Failure,
              SubjectType.Output == Downstream.Input
        {
            lazySubject.subscribe(Inner(parent: self, downstream: subscriber))
        }
        
        // 后续的节点, 都 Attach 到 Subject 上.
        // 前方的节点, 一直不进行真正的 subscribe 操作, 直到 connect 的时候, 才真正的完成线路的搭建.
        public func connect() -> Cancellable {
            return upstream.subscribe(lazySubject)
        }
    }
}

extension Publishers.Multicast {
    // 没有太明白, 这个意义太哪里. 直接把 Downstream 和 Subject 相连会有什么问题. 
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private enum State {
            case ready(upstream: Upstream,
                       downstream: Downstream)
            case subscribed(upstream: Upstream,
                            downstream: Downstream,
                            subjectSubscription: Subscription)
            case terminal
        }
        
        private let lock = UnfairLock.allocate()
        
        private var state: State
        
        fileprivate init(parent: Publishers.Multicast<Upstream, SubjectType>,
                         downstream: Downstream) {
            state = .ready(upstream: parent.upstream, downstream: downstream)
        }
        
        deinit {
            lock.deallocate()
        }
        
        fileprivate var description: String { return "Multicast" }
        
        fileprivate var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        fileprivate var playgroundDescription: Any { return description }
        
        // 这个 Subscription, 是 Subejct.Conduit 对象.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(upstream, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(upstream: upstream,
                                downstream: downstream,
                                subjectSubscription: subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(_, downstream, subjectSubscription) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            let newDemand = downstream.receive(input)
            if newDemand > 0 {
                subjectSubscription.request(newDemand)
            }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(_, downstream, _) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            // 这里的 subjectSubscription 是 Subject 里面的 Conduit 对象.
            subjectSubscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subjectSubscription.cancel()
        }
    }
}
