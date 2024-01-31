//
//  Publishers.ReceiveOn.swift
//
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

extension Publisher {
    /// Specifies the scheduler on which to receive elements from the publisher.
    ///
    /// You use the `receive(on:options:)` operator to receive results and completion on
    /// a specific scheduler, such as performing UI work on the main run loop. In contrast
    /// with `subscribe(on:options:)`, which affects upstream messages,
    /// `receive(on:options:)` changes the execution context of downstream messages.
    ///
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
    ///
    ///     jsonPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receive(on: RunLoop.main)
    ///         .subscribe(labelUpdater)
    ///
    ///
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
    
    /// 指定从发布者接收元素的调度器。
    ///
    /// 使用 `receive(on:options:)` 操作符在特定的调度器上接收结果和完成，例如在主运行循环上执行 UI 工作。与 `subscribe(on:options:)` 不同，
    /// 它影响上游消息，`receive(on:options:)` 改变下游消息的执行上下文。
    ///
    /// 在以下示例中，`subscribe(on:options:)` 操作符导致 `jsonPublisher` 在 `backgroundQueue` 上接收请求，而
    /// `receive(on:options:)` 操作符导致 `labelUpdater` 在 `RunLoop.main` 上接收元素和完成。
    ///
    ///     // 一些发布者。
    ///     let jsonPublisher = MyJSONLoaderPublisher()
    ///
    ///     // 一些更新 UI 的订阅者。
    ///     let labelUpdater = MyLabelUpdateSubscriber()
    ///
    ///     jsonPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receive(on: RunLoop.main)
    ///         .subscribe(labelUpdater)
    ///
    ///
    /// 在执行订阅者中的工作时，建议使用 `receive(on:options:)` 而不是显式使用调度队列。例如，使用以下模式：
    ///
    ///     pub.sink {
    ///         DispatchQueue.main.async {
    ///             // 做一些工作。
    ///         }
    ///     }
    ///
    /// 而不是使用以下模式：
    ///
    ///     pub.receive(on: DispatchQueue.main).sink {
    ///         // 做一些工作。
    ///     }
    ///
    /// > 注意: `receive(on:options:)` 不影响用于调用订阅者的 `receive(subscription:)` 方法的调度器。
    ///
    /// - Parameters:
    ///   - scheduler: 用于元素传递的调度器。
    ///   - options: 用于自定义元素传递的调度器选项。
    /// - Returns: 一个使用指定调度器传递元素的发布者。

    public func receive<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.ReceiveOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

extension Publishers {
    
    /// A publisher that delivers elements to its downstream subscriber on a specific
    /// scheduler.
    public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The scheduler the publisher is to use for element delivery.
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
        private let downstream: Downstream
        private let scheduler: Context
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
        
        // 在接收到上游数据的时候, 进行环境的调度.
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledReceive(input)
            }
            return .none
        }
        
        private func scheduledReceive(_ input: Input) {
            lock.lock()
            // 因为发生了调度, 所以在真正的触发的时候, 还是要判断一下 state 的信息.
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
        
        // 在接收到上游的完成事件的时候, 进行环境的调度.
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
        
        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
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
