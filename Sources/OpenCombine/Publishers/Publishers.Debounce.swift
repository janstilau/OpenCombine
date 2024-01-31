//
//  Publishers.Debounce.swift
//
//
//  Created by Sergej Jaskiewicz on 17.12.2019.
//

extension Publisher {
    
    /// Publishes elements only after a specified time interval elapses between events.
    ///
    /// Use the `debounce(for:scheduler:options:)` operator to control the number of
    /// values and time between delivery of values from the upstream publisher. This
    /// operator is useful to process bursty or high-volume event streams where you need
    /// to reduce the number of values delivered to the downstream to a rate you specify.
    ///
    /// In this example, a `PassthroughSubject` publishes elements on a schedule defined
    /// by the `bounces` array. The array is composed of tuples representing a value sent
    /// by the `PassthroughSubject`, and a `TimeInterval` ranging from one-quarter second
    /// up to 2 seconds that drives a delivery timer. As the queue builds, elements
    /// arriving faster than one-half second `debounceInterval` are discarded, while
    /// elements arriving at a rate slower than `debounceInterval` are passed through to
    /// the `sink(receiveValue:)` operator.
    ///
    ///     let bounces:[(Int,TimeInterval)] = [
    ///         (0, 0),
    ///         (1, 0.25),  // 0.25s interval since last index
    ///         (2, 1),     // 0.75s interval since last index
    ///         (3, 1.25),  // 0.25s interval since last index
    ///         (4, 1.5),   // 0.25s interval since last index
    ///         (5, 2)      // 0.5s interval since last index
    ///     ]
    ///
    ///     let subject = PassthroughSubject<Int, Never>()
    ///     cancellable = subject
    ///         .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
    ///         .sink { index in
    ///             print ("Received index \(index)")
    ///         }
    ///
    ///     for bounce in bounces {
    ///         DispatchQueue.main.asyncAfter(deadline: .now() + bounce.1) {
    ///             subject.send(bounce.0)
    ///         }
    ///     }
    ///
    ///     // Prints:
    ///     //  Received index 1
    ///     //  Received index 4
    ///     //  Received index 5
    ///
    ///     //  Here is the event flow shown from the perspective of time, showing value
    ///     //  delivery through the `debounce()` operator:
    ///
    ///     //  Time 0: Send index 0.
    ///     //  Time 0.25: Send index 1. Index 0 was waiting and is discarded.
    ///     //  Time 0.75: Debounce period ends, publish index 1.
    ///     //  Time 1: Send index 2.
    ///     //  Time 1.25: Send index 3. Index 2 was waiting and is discarded.
    ///     //  Time 1.5: Send index 4. Index 3 was waiting and is discarded.
    ///     //  Time 2: Debounce period ends, publish index 4. Also, send index 5.
    ///     //  Time 2.5: Debounce period ends, publish index 5.
    ///
    /// - Parameters:
    ///   - dueTime: The time the publisher should wait before publishing an element.
    ///   - scheduler: The scheduler on which this publisher delivers elements
    ///   - options: Scheduler options that customize this publisher’s delivery
    ///     of elements.
    /// - Returns: A publisher that publishes events only after a specified time elapses.
    ///
    /// 仅在事件之间经过了指定的时间间隔后发布元素。
    ///
    /// 使用 `debounce(for:scheduler:options:)` 运算符来控制从上游发布者传递的值之间的值和时间数量。此运算符适用于处理突发或高容量事件流，其中您需要将传递到下游的值数量减少到您指定的速率。
    ///
    /// 在此示例中，`PassthroughSubject` 按照 `bounces` 数组定义的时间表发布元素。该数组由表示由 `PassthroughSubject` 发送的值的元组组成，以及从上一个索引到当前索引的时间间隔，时间间隔范围从四分之一秒到2秒，用于驱动传递计时器。随着队列的构建，以小于半秒的 `debounceInterval` 到达的元素将被丢弃，而以小于 `debounceInterval` 的速率到达的元素将通过到 `sink(receiveValue:)` 运算符。
    ///
    ///     let bounces:[(Int,TimeInterval)] = [
    ///         (0, 0),
    ///         (1, 0.25),  // 上一个索引到当前索引的0.25秒时间间隔
    ///         (2, 1),     // 上一个索引到当前索引的0.75秒时间间隔
    ///         (3, 1.25),  // 上一个索引到当前索引的0.25秒时间间隔
    ///         (4, 1.5),   // 上一个索引到当前索引的0.25秒时间间隔
    ///         (5, 2)      // 上一个索引到当前索引的0.5秒时间间隔
    ///     ]
    ///
    ///     let subject = PassthroughSubject<Int, Never>()
    ///     cancellable = subject
    ///         .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
    ///         .sink { index in
    ///             print ("Received index \(index)")
    ///         }
    ///
    ///     for bounce in bounces {
    ///         DispatchQueue.main.asyncAfter(deadline: .now() + bounce.1) {
    ///             subject.send(bounce.0)
    ///         }
    ///     }
    ///
    ///     // 输出:
    ///     //  Received index 1
    ///     //  Received index 4
    ///     //  Received index 5
    ///
    ///     //  以下是从时间的角度显示的事件流，显示通过 `debounce()` 运算符传递的值：
    ///
    ///     //  时间 0: 发送索引 0。
    ///     //  时间 0.25: 发送索引 1。索引 0 等待并被丢弃。
    ///     //  时间 0.75: 防抖周期结束，发布索引 1。
    ///     //  时间 1: 发送索引 2。
    ///     //  时间 1.25: 发送索引 3。索引 2 等待并被丢弃。
    ///     //  时间 1.5: 发送索引 4。索引 3 等待并被丢弃。
    ///     //  时间 2: 防抖周期结束，发布索引 4。同时，发送索引 5。
    ///     //  时间 2.5: 防抖周期结束，发布索引 5。
    ///
    /// - Parameters:
    ///   - dueTime: 元素发布前应等待的时间。
    ///   - scheduler: 传递元素的调度器
    ///   - options: 自定义此发布者传递元素的调度器选项。
    /// - Returns: 一个发布者，仅在指定的时间过去后才发布事件。
    
    // dueTime, 和 options 到底使用哪个类型,是由 scheduler 决定的.
    public func debounce<Context: Scheduler>(
        for dueTime: Context.SchedulerTimeType.Stride,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.Debounce<Self, Context> {
        return .init(upstream: self,
                     dueTime: dueTime,
                     scheduler: scheduler,
                     options: options)
    }
}

extension Publishers {
    
    /// A publisher that publishes elements only after a specified time interval elapses
    /// between events.
    public struct Debounce<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The amount of time the publisher should wait before publishing an element.
        public let dueTime: Context.SchedulerTimeType.Stride
        
        /// The scheduler on which this publisher delivers elements.
        public let scheduler: Context
        
        /// Scheduler options that customize this publisher’s delivery of elements.
        public let options: Context.SchedulerOptions?
        
        public init(upstream: Upstream,
                    dueTime: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.dueTime = dueTime
            self.scheduler = scheduler
            self.options = options
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Failure, Downstream.Input == Output
        {
            let inner = Inner(downstream: subscriber,
                              dueTime: dueTime,
                              scheduler: scheduler,
                              options: options)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Debounce {
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input,
          Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private typealias Generation = UInt64
        
        private enum CancellerState {
            case pending
            case active(Cancellable)
            
            fileprivate func cancel() {
                if case let .active(cancellable) = self {
                    cancellable.cancel()
                }
            }
        }
        
        private let lock = UnfairLock.allocate()
        
        private let downstreamLock = UnfairRecursiveLock.allocate()
        
        private let downstream: Downstream
        
        private let dueTime: Context.SchedulerTimeType.Stride
        
        private let scheduler: Context
        
        private let options: Context.SchedulerOptions?
        
        private var state = SubscriptionStatus.awaitingSubscription
        
        private var currentCancellers = [Generation : CancellerState]()
        
        private var currentValue: Output?
        
        private var currentGeneration: Generation = 0
        
        private var downstreamDemand = Subscribers.Demand.none
        
        init(downstream: Downstream,
             dueTime: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             options: Context.SchedulerOptions?) {
            self.downstream = downstream
            self.dueTime = dueTime
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
            subscription.request(.unlimited)
        }
        
        /*
         Debounce, 就是在 接收到数据和完成事件的时候, 进行 延迟的发送.
         */
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return .none
            }
            currentGeneration += 1
            let generation = currentGeneration
            currentValue = input
            let due = scheduler.now.advanced(by: dueTime)
            let previousCancellers = self.currentCancellers.take()
            currentCancellers[generation] = .pending
            lock.unlock()
            let newCanceller = scheduler.schedule(after: due,
                                                  interval: dueTime,
                                                  tolerance: scheduler.minimumTolerance,
                                                  options: options) {
                // 在 schedule 的回调里面, 才真正的触发数据传送.
                self.due(generation: generation)
            }
            lock.lock()
            currentCancellers[generation] = .active(newCanceller)
            lock.unlock()
            // 把之前的, 所有的都取消了.
            for canceller in previousCancellers.values {
                canceller.cancel()
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
            let previousCancellers = currentCancellers.take()
            lock.unlock()
            for canceller in previousCancellers.values {
                canceller.cancel()
            }
            scheduler.schedule {
                self.downstreamLock.lock()
                self.downstream.receive(completion: completion)
                self.downstreamLock.unlock()
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            lock.unlock()
        }
        
        func cancel() {
            lock.lock()
            guard case .subscribed(let subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            let previousCancellers = currentCancellers.take()
            lock.unlock()
            for canceller in previousCancellers.values {
                canceller.cancel()
            }
            subscription.cancel()
        }
        
        var description: String { return "Debounce" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("downstreamDemand", downstreamDemand),
                ("currentValue", currentValue as Any)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
        
        private func due(generation: Generation) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            
            // If this condition holds, it means that no values were received
            // in this time frame => we should propagate the current value downstream.
            guard generation == currentGeneration, let value = currentValue else {
                let canceller = currentCancellers[generation]
                lock.unlock()
                canceller?.cancel()
                return
            }
            
            guard let canceller = currentCancellers[generation].take() else {
                lock.unlock()
                return
            }
            
            let hasAnyDemand = downstreamDemand != .none
            if hasAnyDemand {
                downstreamDemand -= 1
            }
            
            lock.unlock()
            canceller.cancel()
            
            guard hasAnyDemand else { return }
            
            downstreamLock.lock()
            // 在这里, 才真正的发送了数据. 
            let newDemand = downstream.receive(value)
            downstreamLock.unlock()
            
            if newDemand == .none { return }
            
            lock.lock()
            downstreamDemand += newDemand
            lock.unlock()
        }
    }
}
