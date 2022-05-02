
extension Publisher {
    
    /// Delays delivery of all output to the downstream receiver by a specified amount of
    /// time on a particular scheduler.
    
    /// Use `delay(for:tolerance:scheduler:options:)` when you need to delay the delivery
    /// of elements to a downstream by a specified amount of time.
    
    /// In this example, a `Timer` publishes an event every second.
    /// The `delay(for:tolerance:scheduler:options:)` operator holds the delivery of
    /// the initial element for 3 seconds (±0.5 seconds), after which each element is
    /// delivered to the downstream on the main run loop after the specified delay:
    
    ///
    ///     let df = DateFormatter()
    ///     df.dateStyle = .none
    ///     df.timeStyle = .long
    ///     cancellable = Timer.publish(every: 1.0, on: .main, in: .default)
    ///         .autoconnect()
    ///         .handleEvents(receiveOutput: { date in
    ///             print ("Sending Timestamp \'\(df.string(from: date))\' to delay()")
    ///         })
    ///         .delay(for: .seconds(3), scheduler: RunLoop.main, options: .none)
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)", terminator: "\n") },
    ///             receiveValue: { value in
    ///                 let now = Date()
    ///                 print("""
    ///                 At \(df.string(from: now)) received Timestamp \
    ///                 \'\(df.string(from: value))\' \
    ///                 sent: \(String(format: "%.2f", now.timeIntervalSince(value)))
    ///                 secs ago
    ///                 """)
    ///             }
    ///         )
    ///
    ///     // Prints:
    ///     //    Sending Timestamp '5:02:33 PM PDT' to delay()
    ///     //    Sending Timestamp '5:02:34 PM PDT' to delay()
    ///     //    Sending Timestamp '5:02:35 PM PDT' to delay()
    ///     //    Sending Timestamp '5:02:36 PM PDT' to delay()
    ///     //    At 5:02:36 PM PDT received  Timestamp '5:02:33 PM PDT' sent: 3.00
    ///     //    secs ago
    ///     //    Sending Timestamp '5:02:37 PM PDT' to delay()
    ///     //    At 5:02:37 PM PDT received  Timestamp '5:02:34 PM PDT' sent: 3.00
    ///     //    secs ago
    ///     //    Sending Timestamp '5:02:38 PM PDT' to delay()
    ///     //    At 5:02:38 PM PDT received  Timestamp '5:02:35 PM PDT' sent: 3.00
    ///     //    secs ago
    ///

    /// The delay affects the delivery of elements and completion, but not of the original
    /// subscription.
    // subscription 不会被 Dealy, 各种 Event 事件的传递, 会被 Delay.
    
    /// - Parameters:
    ///   - interval: The amount of time to delay.
    ///   - tolerance: The allowed tolerance in firing delayed events.
    ///   - scheduler: The scheduler to deliver the delayed events.
    ///   - options: Options relevant to the scheduler’s behavior.
    /// - Returns: A publisher that delays delivery of elements and completion to
    ///   the downstream receiver.
    
    // Publisher 的 Operator 方法, 是为了生成对应的 Publisher 对象.
    // Publisher 对象的 Init 方法, 可以确定里面的类型参数.
    // 但是, Publisher 的 Operator 方法的各个参数, 是被 Context 所限制的, 这是泛型的类型绑定的功劳. 所以, 在使用 delay 方法的时候, 要确保各个参数的类型, 是在同一个 Context 的定义条件下.
    public func delay<Context: Scheduler>(
        for interval: Context.SchedulerTimeType.Stride,
        tolerance: Context.SchedulerTimeType.Stride? = nil,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.Delay<Self, Context> {
        return .init(upstream: self,
                     interval: interval,
                     tolerance: tolerance ?? scheduler.minimumTolerance,
                     scheduler: scheduler,
                     options: options)
    }
}

extension Publishers {
    
    // 惯例的 Publisher. 收集数据, 生成 Inner 节点.
    // Delay 的主要作用, 是 DownStream 的各种 receive 动作被 Delay 了.
    /// A publisher that delays delivery of elements and completion
    /// to the downstream receiver.
    // Context 类型的确定, 是在 init 方法中确认的.
    public struct Delay<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream
        
        /// The amount of time to delay.
        public let interval: Context.SchedulerTimeType.Stride
        
        /// The allowed tolerance in firing delayed events.
        public let tolerance: Context.SchedulerTimeType.Stride
        
        /// The scheduler to deliver the delayed events.
        public let scheduler: Context
        
        public let options: Context.SchedulerOptions?
        
        // 各种, Scheduler 所需要的环境数据, 都存到了 Operator 的 Subscription 的内部.
        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    tolerance: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions? = nil)
        {
            self.upstream = upstream
            self.interval = interval
            self.tolerance = tolerance
            self.scheduler = scheduler
            self.options = options
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Upstream.Failure == Downstream.Failure,
              Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber,
                              interval: interval,
                              tolerance: tolerance,
                              scheduler: scheduler,
                              options: options)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Delay {
    
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        // 所有的数据, 都是在 Init 中传递过来的.
        // 这充分表现了, Operator 的实现, 是隐藏起来的.
        private let lock = UnfairLock.allocate()
        private let downstream: Downstream
        private let interval: Context.SchedulerTimeType.Stride
        private let tolerance: Context.SchedulerTimeType.Stride
        private let scheduler: Context
        private let options: Context.SchedulerOptions?
        private var state = SubscriptionStatus.awaitingSubscription
        private let downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate init(downstream: Downstream,
                         interval: Context.SchedulerTimeType.Stride,
                         tolerance: Context.SchedulerTimeType.Stride,
                         scheduler: Context,
                         options: Context.SchedulerOptions?) {
            self.downstream = downstream
            self.interval = interval
            self.tolerance = tolerance
            self.scheduler = scheduler
            self.options = options
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 调度, 调度的是动作. 使用 scheduler 里面定义的接口, 来完成调度这件事.
        // 这里可以看出, Scheduler 这个抽象, 是给 Operator 来使用的.
        // 具体的使用方式, 所需要的参数, 都是在 Operator 生成的 Subscription 中环境中进行的保存.
        private func schedule(_ work: @escaping () -> Void) {
            scheduler
                .schedule(after: scheduler.now.advanced(by: interval),
                          tolerance: tolerance,
                          options: options,
                          work)
        }
        
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            //
            schedule {
                self.scheduledReceive(input)
            }
            return .none
        }
        
        // 当一个节点, 需要实现 Subscription 的时候, 是因为这个节点
        // 1. 可以提前退出, 所以需要在 Receive Input 的时候, 在适当的时机 调用 保存的 Subscription 的 cancel 方法
        // 2. 当下游节点调用 request demand 的方法的时候, 需要进行控制. 
        private func scheduledReceive(_ input: Input) {
            lock.lock()
            guard state.subscription != nil else {
                lock.unlock()
                return
            }
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand == .none { return }
            lock.lock()
            let subscription = state.subscription
            lock.unlock()
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
            schedule {
                self.scheduledReceive(completion: completion)
            }
        }
        
        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .pendingTerminal = state else {
                assertionFailure(
                    "This branch should not be reachable! Please report a bug."
                )
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            // 可以看到, Schedule 相关的 Operator, 也是没有管理 Demand 的能力. 仅仅是传递给上级节点. 
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
    }
}
