
extension Publisher {
    
    /// Terminates publishing if the upstream publisher exceeds the specified time
    /// interval without producing an element.
    // 不过, 不能在时间范围内发射新的信号, 这个 Publisher 就 cancel 掉了
    
    /// Use `timeout(_:scheduler:options:customError:)` to terminate a publisher if
    /// an element isn’t delivered within a timeout interval you specify.
    
    /// In the example below, a `PassthroughSubject` publishes `String` elements and is
    /// configured to time out if no new elements are received within its `TIME_OUT`
    /// window of 5 seconds. A single value is published after the specified 2-second
    /// `WAIT_TIME`, after which no more elements are available; the publisher then times
    /// out and completes normally.
    
    ///     var WAIT_TIME : Int = 2
    ///     var TIMEOUT_TIME : Int = 5
    ///
    ///     let subject = PassthroughSubject<String, Never>()
    ///     let cancellable = subject
    ///         .timeout(.seconds(TIMEOUT_TIME),
    ///                  scheduler: DispatchQueue.main,
    ///                  options: nil,
    ///                  customError: nil)
    ///         .sink(
    ///               receiveCompletion: { print ("completion: \($0) at \(Date())") },
    ///               receiveValue: { print ("value: \($0) at \(Date())") }
    ///          )
    ///
    ///     DispatchQueue.main.asyncAfter(
    ///         deadline: .now() + .seconds(WAIT_TIME),
    ///         execute: {
    ///             subject.send("Some data - sent after a delay of \(WAIT_TIME) seconds")
    ///         }
    ///     )
    ///
    ///     // Prints:
    ///     //   value: Some data - sent after a delay of 2 seconds at
    ///     //          2020-03-10 23:47:59 +0000
    ///     //   completion: finished at 2020-03-10 23:48:04 +0000
    
    /// If `customError` is `nil`, the publisher completes normally; if you provide
    /// a closure for the `customError` argument, the upstream publisher is instead
    /// terminated upon timeout, and the error is delivered to the downstream.
    
    /// - Parameters:
    ///   - interval: The maximum time interval the publisher can go without emitting
    ///     an element, expressed in the time system of the scheduler.
    ///   - scheduler: The scheduler to deliver events on.
    ///   - options: Scheduler options that customize the delivery of elements.
    ///   - customError: A closure that executes if the publisher times out.
    ///     The publisher sends the failure returned by this closure to the subscriber as
    ///     the reason for termination.
    /// - Returns: A publisher that terminates if the specified interval elapses with no
    ///   events received from the upstream publisher.
    
    public func timeout<Context: Scheduler>(
        _ interval: Context.SchedulerTimeType.Stride,
        scheduler: Context,
        options: Context.SchedulerOptions? = nil,
        // 当, 一段时间没有信号产生之后, 下游节点会受到这个闭包产生的错误. 如果这里没有传入, 那么下游节点, 会收到 Finish 事件.
        customError: (() -> Failure)? = nil
    ) -> Publishers.Timeout<Self, Context> {
        return .init(upstream: self,
                     interval: interval,
                     scheduler: scheduler,
                     options: options,
                     customError: customError)
    }
}

extension Publishers {
    
    public struct Timeout<Upstream: Publisher, Context: Scheduler>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        public let upstream: Upstream
        
        public let interval: Context.SchedulerTimeType.Stride
        
        public let scheduler: Context
        
        public let options: Context.SchedulerOptions?
        
        public let customError: (() -> Upstream.Failure)?
        
        public init(upstream: Upstream,
                    interval: Context.SchedulerTimeType.Stride,
                    scheduler: Context,
                    options: Context.SchedulerOptions?,
                    customError: (() -> Publishers.Timeout<Upstream, Context>.Failure)?) {
            self.upstream = upstream
            self.interval = interval
            self.scheduler = scheduler
            self.options = options
            self.customError = customError
        }
        
        public func receive<Downsteam: Subscriber>(subscriber: Downsteam)
        where Downsteam.Failure == Failure, Downsteam.Input == Output
        {
            let inner = Inner(downstream: subscriber,
                              interval: interval,
                              scheduler: scheduler,
                              options: options,
                              customError: customError)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Timeout {
    
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure {
        
        // 各种, 都是 Private 的作用域. 都是通过 Init 方法传入或者默认生成的.
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let lock = UnfairLock.allocate()
        
        private let downstreamLock = UnfairRecursiveLock.allocate()
        
        private let downstream: Downstream
        
        private let interval: Context.SchedulerTimeType.Stride
        
        private let scheduler: Context
        
        private let options: Context.SchedulerOptions?
        
        private let customError: (() -> Upstream.Failure)?
        
        private var state = SubscriptionStatus.awaitingSubscription
        
        private var didTimeout = false
        
        private var timerInvalidateTrigger: AnyCancellable?
        
        private var initialDemand = false
        
        init(downstream: Downstream,
             interval: Context.SchedulerTimeType.Stride,
             scheduler: Context,
             options: Context.SchedulerOptions?,
             customError: (() -> Upstream.Failure)?) {
            self.downstream = downstream
            self.interval = interval
            self.scheduler = scheduler
            self.options = options
            self.customError = customError
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
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
            timerInvalidateTrigger = timeoutClock()
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            // 业务相关处理. 如果, 已经 timeout 了, 根本不触发后面的逻辑.
            guard !didTimeout, case .subscribed = state else {
                lock.unlock()
                return .none
            }
            // 每次, 收到上游数据之后, 都重置 TerminateTimeout 的值.
            timerInvalidateTrigger?.cancel()
            didTimeout = false
            // 然后重新设置 TimerOut 的 timer.
            timerInvalidateTrigger = timeoutClock()
            lock.unlock()
            // 这里为什么还要调度一次.
            scheduler.schedule(options: options) {
                self.scheduledReceive(input)
            }
            return .none
        }
        
        private func scheduledReceive(_ input: Input) {
            lock.lock()
            guard !didTimeout, case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            if newDemand != .none {
                subscription.request(newDemand)
            }
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
                lock.unlock()
                return
            }
            timerInvalidateTrigger?.cancel()
            lock.unlock()
            scheduler.schedule(options: options) {
                self.scheduledReceive(completion: completion)
            }
        }
        
        private func scheduledReceive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case .subscribed = state else {
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
            // 第一次, 也要触发 TimerOut 的定时器.
            if !initialDemand {
                timerInvalidateTrigger = timeoutClock()
                initialDemand = true
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
            timerInvalidateTrigger?.cancel()
            subscription.cancel()
        }
        
        var description: String { return "Timeout" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
        
        private func timedOut() {
            lock.lock()
            guard !didTimeout, case let .subscribed(subscription) = state else {
                lock.unlock()
                return
            }
            // 超时 Timeout 的回调.
            didTimeout = true
            state = .terminal
            lock.unlock()
            // 当, 已经 TimerOut 了, 主动的触发上层节点的 cancel.
            subscription.cancel()
            downstreamLock.lock()
            // 主动触发下层节点的 Completion 事件.
            downstream
                .receive(completion: customError.map { .failure($0()) } ?? .finished)
            downstreamLock.unlock()
        }
        
        private func timeoutClock() -> AnyCancellable {
            // 一个单次的定时器, 来触发超时的相关逻辑.
            // 可以看到, 其实单词的定时器, 使用的也很频繁. 
            let cancellable = scheduler
                .schedule(after: scheduler.now.advanced(by: interval),
                          interval: interval,
                          tolerance: scheduler.minimumTolerance,
                          options: options,
                          timedOut)
            return AnyCancellable(cancellable.cancel)
        }
    }
}
