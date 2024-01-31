//
//  Publishers.MeasureInterval.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

extension Publisher {

    /// Measures and emits the time interval between events received from an upstream
    /// publisher.
    ///
    /// Use `measureInterval(using:options:)` to measure the time between events delivered
    /// from an upstream publisher.
    ///
    /// In the example below, a 1-second `Timer` is used as the data source for an event
    /// publisher; the `measureInterval(using:options:)` operator reports the elapsed time
    /// between the reception of events on the main run loop:
    ///
    ///     cancellable = Timer.publish(every: 1, on: .main, in: .default)
    ///         .autoconnect()
    ///         .measureInterval(using: RunLoop.main)
    ///         .sink { print("\($0)", terminator: "\n") }
    ///
    ///     // Prints:
    ///     //      Stride(magnitude: 1.0013610124588013)
    ///     //      Stride(magnitude: 0.9992760419845581)
    ///
    /// The output type of the returned publisher is the time interval of the provided
    /// scheduler.
    ///
    /// This operator uses the provided scheduler’s `now` property to measure intervals
    /// between events.
    ///
    /// - Parameters:
    ///   - scheduler: A scheduler to use for tracking the timing of events.
    ///   - options: Options that customize the delivery of elements.
    /// - Returns: A publisher that emits elements representing the time interval between
    ///   the elements it receives.
    
    /// 测量并发出从上游发布者接收的事件之间的时间间隔。
    ///
    /// 使用 `measureInterval(using:options:)` 来测量从上游发布者传递的事件之间的时间。
    ///
    /// 在下面的示例中，一个1秒的 `Timer` 被用作事件发布者的数据源；`measureInterval(using:options:)` 操作符报告了在主运行循环上接收事件之间经过的时间：
    ///
    ///     cancellable = Timer.publish(every: 1, on: .main, in: .default)
    ///         .autoconnect()
    ///         .measureInterval(using: RunLoop.main)
    ///         .sink { print("\($0)", terminator: "\n") }
    ///
    ///     // Prints:
    ///     //      Stride(magnitude: 1.0013610124588013)
    ///     //      Stride(magnitude: 0.9992760419845581)
    ///
    /// 返回的发布者的输出类型是所提供调度器的时间间隔。
    ///
    /// 该操作符使用所提供调度器的 `now` 属性来测量事件之间的间隔。
    ///
    /// - Parameters:
    ///   - scheduler: 用于跟踪事件定时的调度器。
    ///   - options: 自定义元素传递的选项。
    /// - Returns: 一个发布者，发出代表接收到的元素之间时间间隔的元素。

    public func measureInterval<Context: Scheduler>(
        using scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.MeasureInterval<Self, Context> {
        return .init(upstream: self, scheduler: scheduler)
    }
}

extension Publishers {

    /// A publisher that measures and emits the time interval between events received from
    /// an upstream publisher.
    public struct MeasureInterval<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Context.SchedulerTimeType.Stride

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The scheduler used for tracking the timing of events.
        public let scheduler: Context

        /// Creates a publisher that measures and emits the time interval between events
        /// received from an upstream publisher.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - scheduler: A scheduler to use for tracking the timing of events.
        public init(upstream: Upstream, scheduler: Context) {
            self.upstream = upstream
            self.scheduler = scheduler
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Downstream.Input == Context.SchedulerTimeType.Stride
        {
            upstream.subscribe(Inner(scheduler: scheduler, downstream: subscriber))
        }
    }
}

extension Publishers.MeasureInterval {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Context.SchedulerTimeType.Stride,
              Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let lock = UnfairLock.allocate()

        private let downstream: Downstream

        private let scheduler: Context

        private var state = SubscriptionStatus.awaitingSubscription

        private var last: Context.SchedulerTimeType?

        init(scheduler: Context, downstream: Downstream) {
            self.downstream = downstream
            self.scheduler = scheduler
        }

        deinit {
            lock.deallocate()
        }

        // 惯例实现.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            last = scheduler.now
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(subscription) = state,
                  let previousTime = last else
            {
                lock.unlock()
                return .none
            }
            let now = scheduler.now
            last = now
            lock.unlock()
            // 收到的数据, 是事件间隔.
            let newDemand = downstream.receive(previousTime.distance(to: now))
            if newDemand > 0 {
                subscription.request(newDemand)
            }
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            state = .terminal
            last = nil
            lock.unlock()
            downstream.receive(completion: completion)
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
            last = nil
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "MeasureInterval" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
