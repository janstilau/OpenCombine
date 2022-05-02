
// 该 Sink 节点, 不会做任何的数据操作, 或者中间节点的插入.
// 它所做的, 就是调度, 将下游节点接收到上游节点这件事, 进行了调度.
extension Publisher {
    /// Specifies the scheduler on which to receive elements from the publisher.
    
    /// You use the `receive(on:options:)` operator to receive results and completion on
    /// a specific scheduler, such as performing UI work on the main run loop. In contrast
    /// with `subscribe(on:options:)`, which affects upstream messages,
    /// `receive(on:options:)` changes the execution context of downstream messages.
    
    /// In the following example, the `subscribe(on:options:)` operator causes
    /// `jsonPublisher` to receive requests on `backgroundQueue`, while
    /// the `receive(on:options:)` causes `labelUpdater` to receive elements and
    /// completion on `RunLoop.main`.
    ///
    ///     // Some publisher.
    ///     let jsonPublisher = MyJSONLoaderPublisher()
    ///
    ///     // Some subscriber that updates the UI.
    ///     let labelUpdater = MyLabelUpdateSubscriber()
    
    
    // subscribe(on 在 Combine 里面, 会使用的很多. 因为它代表的是, 信号的产生逻辑, 应该在哪个环境被使用.
    // 按照 Combine 的 Pull 设计, 上游节点 Subscription, 在接收到下游的 RequestDemand 的时候, 来触发真正的信号产生逻辑, 所以, subscribe(on 会影响到这部分的逻辑发生的环境.
    ///     jsonPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receive(on: RunLoop.main)
    ///         .subscribe(labelUpdater)

    
    // 倾向于使用调度器, 来进行后续链路的搭建. 因为 Operator 就是, 各个业务节点的分割, 然后组成一副复杂的业务逻辑流.
    // 将, 任务分割出去, 使得各个业务节点可以在简单的逻辑中, 完成自己的任务 .
    /// Prefer `receive(on:options:)` over explicit use of dispatch queues when performing
    /// work in subscribers. For example, instead of the following pattern:
    ///
    ///     pub.sink {
    ///         DispatchQueue.main.async {
    ///             // Do something.
    ///         }
    ///     }
    ///
    /// Use this pattern instead:
    ///
    ///     pub.receive(on: DispatchQueue.main).sink {
    ///         // Do something.
    ///     }
    ///
    ///  > Note: `receive(on:options:)` doesn’t affect the scheduler used to cal
    ///  the subscriber’s `receive(subscription:)` method.
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler the publisher uses for element delivery.
    ///   - options: Scheduler options used to customize element delivery.
    /// - Returns: A publisher that delivers elements using the specified scheduler.
    
    /*
     这里又使用了泛型的类型绑定的机制.
     传入的 scheduler 参数, 会限制住真正使用的类型, 泛型方法一定要在真正使用的时候, 能够确定具体的类型, 才能够编译通过.
     scheduler 的确定, 就代表着 options 参数的确定. 如果传入的参数不匹配, 编译报错.
     */
    public func receive<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.ReceiveOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

extension Publishers {

    /// A publisher that delivers elements to its downstream subscriber on a specific scheduler.
    public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        // 记录的上游节点的 Producer.
        // 在 Combine 里面, 几乎所有的 Producer, 都是 值语义的.
        // 这没有问题, 因为他们的数据, 都是为了拷贝到各个生成的节点中.
        public let upstream: Upstream
        
        /// The scheduler the publisher is to use for element delivery.
        // 具体的调度器对象, 这是在 Operator 方法中传入的.
        public let scheduler: Context
        
        /// Scheduler options that customize the delivery of elements.
        // 具体的调度器对象的 Option, 这是在 Operator 方法中传入的.
        public let options: Context.SchedulerOptions?
        
        public init(upstream: Upstream,
                    scheduler: Context,
                    options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.scheduler = scheduler
            self.options = options
        }
        
        // 真正的生成 Subscription 节点. 真正的响应链路里面, 是该节点组成的处理链路.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
        {
            let inner = Inner(scheduler: scheduler,
                              options: options,
                              downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.ReceiveOn {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private let lock = UnfairLock.allocate()
        // 下游节点.
        private let downstream: Downstream
        // 调度器
        private let scheduler: Context
        // 调度器所匹配的 Options.
        private let options: Context.SchedulerOptions?
        private var state = SubscriptionStatus.awaitingSubscription
        private let downstreamLock = UnfairRecursiveLock.allocate()
        
        init(scheduler: Context,
             options: Context.SchedulerOptions?,
             downstream: Downstream) {
            self.downstream = downstream
            self.scheduler = scheduler
            self.options = options
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // Subscriber 的实现.
        // 对于上游节点的接收, 这里没有使用调度器.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 上游节点记录.
            state = .subscribed(subscription)
            lock.unlock()
            downstreamLock.lock()
            // 将自己作为 Subscription, 交给下游节点记录.
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }
        
        // 对于, 上游节点数据的接收, 使用到了调度器.
        /*
         这也能结束, 为什么 ReceiveOn 会是一个 Subscription.
         因为, 在 receive(_ input: Input) 中, 其实会有 Demand 的管理的. 所以这里要缓存一下上游节点 subscription, 在被调度的环境里面, 真正触发下游节点的 receive(_ input: Input) -> Subscribers.Demand, 然后使用返回值, 向上游进行 demand 的 request 操作.
         而一旦在当前节点, 要用到上游节点的 subscription, 就要实现 Subscription 抽象, 哪怕是简单的转交工作.
         在 Combine 的响应链中, 这种转交发生的非常频繁.
         */
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            // 调度这回事, 就是在相应的环境里面, 进行后方节点接受事件的触发.
            scheduler.schedule(options: options) {
                self.scheduledReceive(input)
            }
            // receive(_ input: Input) 里面, 返回 .None, 不会影响到上游节点的 Demand 管理.
            return .none
        }
        
        // 真正的将数据交给下游节点的逻辑在这里.
        // 所以, 实际上, 是在这里进行下游节点的 Demand 管理.
        // 将, Subscription 进行存储, 就可以实现, 在特定的环境进行 Request 来管理上游节点信号发送的目的.
        private func scheduledReceive(_ input: Input) {
            lock.lock()
            // 因为, 是异步操作, 所以到了对应的线程和时间之后, 要检查一下当前的状态.
            // 这一定要在锁的环境下.
            guard state.subscription != nil else {
                lock.unlock()
                return
            }
            lock.unlock()
            downstreamLock.lock()
            // 下游节点, 真正的接收到数据, 是在这里.
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            // 根据, 下游节点的真正的 Demand 的数据, 进行 subscription 的 demand 管理.
            if newDemand == .none { return }
            lock.lock()
            let subscription = state.subscription
            lock.unlock()
            // 在 Subscriber 的相关方法里面, 调用了上游节点 subscription 的方法, 所以, 该节点, 要实现 Subscription 抽象
            subscription?.request(newDemand)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .pendingTerminal(subscription)
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledReceive(completion: completion)
            }
        }
        
        // 和 receiveValue 一样, 只不过, 这次传递的是一个 Subscribers.Completion 数据.
        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            state = .terminal
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
        
        
        // 对于, Subscription 的实现, 完全都是转交的工作.
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
        }
        
        var description: String { return "ReceiveOn" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
    }
}
