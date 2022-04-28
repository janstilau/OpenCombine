/*
 就是 Do 节点.
 */
extension Publisher {
    /// Performs the specified closures when publisher events occur.
    ///
    /// Use `handleEvents` when you want to examine elements as they progress through
    /// the stages of the publisher’s lifecycle.
    // 这个节点, 不会对于原来的数据, 进行任何的操作. 只是在中间, 使用数据进行附加的操作.
    // 例如, 在各个示例程序里面, 都是使用这个节点, 进行的缓存处理.
    
    //
    /// In the example below, a publisher of integers shows the effect of printing
    /// debugging information at each stage of the element-processing lifecycle:
    ///
    ///     let integers = (0...2)
    ///     // 在 HandleEvent 的时候, 要注意传递过来的数据, 是不是值语义的. 如果不是, 那么在各个 Closure 里面, 对参数进行修改, 都是一个值的思考的事情 .
    ///     cancellable = integers.publisher
    ///         .handleEvents(receiveSubscription: { subs in
    ///         // 直接把 Subscription 数据传递过来了.
    ///             print("Subscription: \(subs.combineIdentifier)")
    ///         }, receiveOutput: { anInt in
    ///         // 直接把各个 Value 的数据传递过来了.
    ///             print("in output handler, received \(anInt)")
    ///         }, receiveCompletion: { _ in
    ///         // 直接把结束事件 Enum 传递过来了.
    ///             print("in completion handler")
    ///         }, receiveCancel: {
    ///         // 没有任何的数据, 仅仅是触发.
    ///             print("received cancel")
    ///         }, receiveRequest: { (demand) in
    ///         // 直接把 Demand 传递过来了
    ///             print("received demand: \(demand.description)")
    ///         })
    ///         .sink { _ in return }
    ///
    ///     // Prints:
    ///     //   received demand: unlimited
    ///     //   Subscription: 0x7f81284734c0
    ///     //   in output handler, received 0
    ///     //   in output handler, received 1
    ///     //   in output handler, received 2
    ///     //   in completion handler
    
    
    /// - Parameters:
    ///   - receiveSubscription: A closure that executes when the publisher receives
    ///     the subscription from the upstream publisher. Defaults to `nil`.
    ///   - receiveOutput: A closure that executes when the publisher receives a value
    ///     from the upstream publisher. Defaults to `nil`.
    ///   - receiveCompletion: A closure that executes when the publisher receives
    ///     the completion from the upstream publisher. Defaults to `nil`.
    ///   - receiveCancel: A closure that executes when the downstream receiver cancels
    ///     publishing. Defaults to `nil`.
    ///   - receiveRequest: A closure that executes when the publisher receives a request
    ///     for more elements. Defaults to `nil`.
    /// - Returns: A publisher that performs the specified closures when publisher events
    ///   occur.
    ///
    
    // 按照惯例, 方法里面, 是生成对应的 Publisher. 而这个 Publisher, 最主要的工作, 就是进行值的存储.
    public func handleEvents(
        receiveSubscription: ((Subscription) -> Void)? = nil,
        receiveOutput: ((Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil,
        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        return .init(upstream: self,
                     receiveSubscription: receiveSubscription,
                     receiveOutput: receiveOutput,
                     receiveCompletion: receiveCompletion,
                     receiveCancel: receiveCancel,
                     receiveRequest: receiveRequest)
    }
}

extension Publishers {
    
    /// A publisher that performs the specified closures when publisher events occur.
    public struct HandleEvents<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        // 按照管理, 各个 Publisher, 仅仅是进行数据的收集. 真正的业务逻辑, 是各个 Publisher 的 Inner 对象.
        // 将, Publisher 收集到的各个数据, 存储到对应的 Inner 对象里面.
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// A closure that executes when the publisher receives the subscription from
        /// the upstream publisher.
        public var receiveSubscription: ((Subscription) -> Void)?
        
        ///  A closure that executes when the publisher receives a value from the upstream
        ///  publisher.
        public var receiveOutput: ((Upstream.Output) -> Void)?
        
        /// A closure that executes when the publisher receives the completion from
        /// the upstream publisher.
        public var receiveCompletion:
        ((Subscribers.Completion<Upstream.Failure>) -> Void)?
        
        ///  A closure that executes when the downstream receiver cancels publishing.
        public var receiveCancel: (() -> Void)?
        
        /// A closure that executes when the publisher receives a request for more
        /// elements.
        public var receiveRequest: ((Subscribers.Demand) -> Void)?
        
        public init(
            upstream: Upstream,
            receiveSubscription: ((Subscription) -> Void)? = nil,
            receiveOutput: ((Output) -> Void)? = nil,
            receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
            receiveCancel: (() -> Void)? = nil,
            receiveRequest: ((Subscribers.Demand) -> Void)?
        ) {
            self.upstream = upstream
            self.receiveSubscription = receiveSubscription
            self.receiveOutput = receiveOutput
            self.receiveCompletion = receiveCompletion
            self.receiveCancel = receiveCancel
            self.receiveRequest = receiveRequest
        }
        
        // 生成对应的 Inner 节点, 并且触发上游节点, 进行注册的过程.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
        {
            let inner = Inner(self, downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.HandleEvents {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private var status = SubscriptionStatus.awaitingSubscription
        private let lock = UnfairLock.allocate()
        public var receiveSubscription: ((Subscription) -> Void)?
        public var receiveOutput: ((Upstream.Output) -> Void)?
        public var receiveCompletion:
        ((Subscribers.Completion<Upstream.Failure>) -> Void)?
        public var receiveCancel: (() -> Void)?
        public var receiveRequest: ((Subscribers.Demand) -> Void)?
        private let downstream: Downstream
        
        init(_ events: Publishers.HandleEvents<Upstream>, downstream: Downstream) {
            self.receiveSubscription = events.receiveSubscription
            self.receiveOutput = events.receiveOutput
            self.receiveCompletion = events.receiveCompletion
            self.receiveCancel = events.receiveCancel
            self.receiveRequest = events.receiveRequest
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 对于一般的节点来说, 当收到 Subscription 对象之后进行存储.
        /*
         1. 循环引用的创建.
         2. 当 下游节点进行 Request Demand 的时候, 当下游节点进行 cancel 的时候, forward 相关的操作, 到上游节点 Subscrpiton 当中
         3. 如果有具体的操作, 在相应的方法里面, 读取 Subscription 触发对应操作.
         */
        func receive(subscription: Subscription) {
            lock.lock()
            if let receiveSubscription = self.receiveSubscription {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveSubscription(subscription)
                lock.lock()
            }
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 状态的存储
            status = .subscribed(subscription)
            lock.unlock()
            // 下游节点, 接受自己当做 Subscription
            downstream.receive(subscription: self)
        }
        
        // 和一般的节点所做的没有任何的区别, 在里面, 调用了对应的埋点逻辑.
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if let receiveOutput = self.receiveOutput {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveOutput(input)
            } else {
                lock.unlock()
            }
            let newDemand = downstream.receive(input)
            if newDemand == .none {
                return newDemand
            }
            lock.lock()
            if let receiveRequest = self.receiveRequest {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveRequest(newDemand)
            } else {
                lock.unlock()
            }
            return newDemand
        }
        
        // 和一般的节点没有任何的曲解, 在里面调用了相关的埋点程序.
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            if let receiveCompletion = self.receiveCompletion {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveCompletion(completion)
                lock.lock()
            }
            lockedTerminate()
            lock.unlock()
            downstream.receive(completion: completion)
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            if let receiveRequest = self.receiveRequest {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveRequest(demand)
                lock.lock()
            }
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            // 直接, 转交给了上级节点.
            subscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            if let receiveCancel = self.receiveCancel {
                lock.unlock()
                // HandleEvent 的业务触发点, 调用埋点的闭包对象.
                receiveCancel()
                lock.lock()
            }
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lockedTerminate()
            lock.unlock()
            subscription.cancel()
        }
        
        var description: String { return "HandleEvents" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
        
        private func lockedTerminate() {
            receiveSubscription = nil
            receiveOutput       = nil
            receiveCompletion   = nil
            receiveCancel       = nil
            receiveRequest      = nil
            status = .terminal
        }
    }
}
