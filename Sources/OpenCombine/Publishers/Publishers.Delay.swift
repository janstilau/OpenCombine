//
//  Publishers.Delay.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 07/09/2019.
//

extension Publisher {
    
    /// Delays delivery of all output to the downstream receiver by a specified amount of
    /// time on a particular scheduler.
    ///
    /// Use `delay(for:tolerance:scheduler:options:)` when you need to delay the delivery
    /// of elements to a downstream by a specified amount of time.
    ///
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
    ///
    /// - Parameters:
    ///   - interval: The amount of time to delay.
    ///   - tolerance: The allowed tolerance in firing delayed events.
    ///   - scheduler: The scheduler to deliver the delayed events.
    ///   - options: Options relevant to the scheduler’s behavior.
    /// - Returns: A publisher that delays delivery of elements and completion to
    ///   the downstream receiver.
    /// 将所有输出的传递延迟到下游接收器指定的时间段，使用特定的调度器。
    ///
    /// 当需要延迟元素传递到下游一定时间时，请使用 `delay(for:tolerance:scheduler:options:)`。
    ///
    /// 在此示例中，一个 `Timer` 每秒发布一个事件。
    /// `delay(for:tolerance:scheduler:options:)` 操作符将初始元素的传递延迟了 3 秒（±0.5 秒），
    /// 之后每个元素都在指定的延迟后在主运行循环中传递到下游：
    ///
    ///     let df = DateFormatter()
    ///     df.dateStyle = .none
    ///     df.timeStyle = .long
    ///     cancellable = Timer.publish(every: 1.0, on: .main, in: .default)
    ///         .autoconnect()
    ///         .handleEvents(receiveOutput: { date in
    ///             print ("Sending Timestamp '\(df.string(from: date))' to delay()")
    ///         })
    ///         .delay(for: .seconds(3), scheduler: RunLoop.main, options: .none)
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)", terminator: "\n") },
    ///             receiveValue: { value in
    ///                 let now = Date()
    ///                 print("""
    ///                 At \(df.string(from: now)) received Timestamp \
    ///                 '\(df.string(from: value))' \
    ///                 sent: \(String(format: "%.2f", now.timeIntervalSince(value)))
    ///                 secs ago
    ///                 """)
    ///             }
    ///         )
    ///
    ///     // 打印:
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
    /// 延迟影响元素和完成的传递，但不影响原始订阅。
    ///
    /// - Parameters:
    ///   - interval: 要延迟的时间量。
    ///   - tolerance: 允许的延迟事件触发的容差。
    ///   - scheduler: 提供延迟事件的调度器。
    ///   - options: 与调度器行为相关的选项。
    /// - Returns: 一个发布者，它将元素和完成的传递延迟到下游接收器。

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
    
    /// A publisher that delays delivery of elements and completion
    /// to the downstream receiver.
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
            schedule {
                self.scheduledReceive(input)
            }
            return .none
        }
        
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
