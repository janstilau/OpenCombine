
extension Publisher {
    
    /*
     相比较, receive(on:options:) 是影响到下游节点的 receive Value, receive Completion.
     subscribe(on 则是针对上游节点的各个事件. 而且, 和 Rx 里仅仅影响 subscribe 方法不同, subscribe, cancel, and request  都会在对应的环境中触发.
     */
    
    /// Specifies the scheduler on which to perform subscribe, cancel, and request
    /// operations.
    
    //
    /// In contrast with `receive(on:options:)`, which affects downstream messages,
    /// `subscribe(on:options:)` changes the execution context of upstream messages.
    
    /// In the following example, the `subscribe(on:options:)` operator causes
    /// `ioPerformingPublisher` to receive requests on `backgroundQueue`, while
    /// the `receive(on:options:)` causes `uiUpdatingSubscriber` to receive elements and
    /// completion on `RunLoop.main`.
    ///
    ///     let ioPerformingPublisher == // Some publisher.
    ///     let uiUpdatingSubscriber == // Some subscriber that updates the UI.
    ///
    ///     ioPerformingPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receive(on: RunLoop.main)
    ///         .subscribe(uiUpdatingSubscriber)
    ///
    ///
    /// Using `subscribe(on:options:)` also causes the upstream publisher to perform
    /// `cancel()` using the specfied scheduler.
    
    
    /// - Parameters:
    ///   - scheduler: The scheduler used to send messages to upstream publishers.
    ///   - options: Options that customize the delivery of elements.
    /// - Returns: A publisher which performs upstream operations on the specified
    ///   scheduler.
    
    // 按照惯例, Operator 方法, 是生成 Operator 的过程.
    public func subscribe<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.SubscribeOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

extension Publishers {
    
    // 真正的 Operator Publisher 结构.
    /// A publisher that receives elements from an upstream publisher on a specific
    /// scheduler.
    public struct SubscribeOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The scheduler the publisher should use to receive elements.
        public let scheduler: Context
        
        /// Scheduler options that customize the delivery of elements.
        public let options: Context.SchedulerOptions?
        
        public init(upstream: Upstream,
                    scheduler: Context,
                    options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.scheduler = scheduler
            self.options = options
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
        {
            let inner = Inner(scheduler: scheduler,
                              options: options,
                              downstream: subscriber)
            // 在指定的调度器, 来完成 attach 这个行为.
            scheduler.schedule(options: options) {
                self.upstream.subscribe(inner)
            }
        }
    }
}

extension Publishers.SubscribeOn {
    
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
        private let downstream: Downstream
        private let scheduler: Context
        private let options: Context.SchedulerOptions?
        private var state = SubscriptionStatus.awaitingSubscription
        private let upstreamLock = UnfairLock.allocate()
        
        init(scheduler: Context,
             options: Context.SchedulerOptions?,
             downstream: Downstream) {
            self.downstream = downstream
            self.scheduler = scheduler
            self.options = options
        }
        
        deinit {
            lock.deallocate()
            upstreamLock.deallocate()
        }
        
        // 收到, 上游节点的事件, 没有调度.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }
        
        // 收到, 上游节点 Next, 没有调度. 直接传递给下游节点, Forward 的逻辑.
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }
        
        // 收到, 上游节点的结束事件, 没有调度. 直接传递给了下游节点. Forward 逻辑.
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
        
        // 收到, 下游节点的 Request Demand 的时间.
        // 调度, 在对应的环境中, 完整真正的 Demand 管理.
        // 一般来说, 真正的触发产生信号的逻辑, 就在该方法里面, 所以在这个方法里面调度, 其实才能将耗时操作转移到对应调度器环境.
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledRequest(demand, subscription: subscription)
            }
        }
        
        // 调用, 存储的 subscription, 进行真正的 Demand 管理. 该函数发生的时候, 一定是在调度后的环境.
        private func scheduledRequest(_ demand: Subscribers.Demand,
                                      subscription: Subscription) {
            upstreamLock.lock()
            subscription.request(demand)
            upstreamLock.unlock()
        }
        
        // Cancel 事件, 进行调度.
        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledCancel(subscription)
            }
        }
        
        private func scheduledCancel(_ subscription: Subscription) {
            upstreamLock.lock()
            subscription.cancel()
            upstreamLock.unlock()
        }
        
        var description: String { return "SubscribeOn" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
    }
}
