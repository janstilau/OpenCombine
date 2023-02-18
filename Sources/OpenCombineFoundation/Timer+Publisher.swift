
import Foundation
import OpenCombine

extension Foundation.Timer {
    
    /// Returns a publisher that repeatedly emits the current date on the given interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval on which to publish events. For example,
    ///     a value of `0.5` publishes an event approximately every half-second.
    ///   - tolerance: The allowed timing variance when emitting events.
    ///     Defaults to `nil`, which allows any variance.
    ///   - runLoop: The run loop on which the timer runs.
    ///   - mode: The run loop mode in which to run the timer.
    ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
    /// - Returns: A publisher that repeatedly emits the current date on the given
    ///   interval.
    public static func publish(
        every interval: TimeInterval,
        tolerance _: TimeInterval? = nil,
        on runLoop: RunLoop,
        in mode: RunLoop.Mode,
        options: RunLoop.OCombine.SchedulerOptions? = nil
    ) -> OCombine.TimerPublisher {
        // A bug in Combine: tolerance is ignored.
        return .init(interval: interval, runLoop: runLoop, mode: mode, options: options)
    }
    
    public enum OCombine {
        
        /// A publisher that repeatedly emits the current date on a given interval.
        // TimerPublisher 本身就实现了多 subsriber 管理的需求.
        // 或许应该这样说, ConnectablePublisher 在实现的时候, 应该就是想到如何实现多 subsriber
        // 因为它出现的目的, 就是多个 scriber attach 之后, 才触发上游的信号产生. 所以存储下游是必然发生的事情. 
        public final class TimerPublisher: ConnectablePublisher {
            public typealias Output = Date
            public typealias Failure = Never
            
            public let interval: TimeInterval
            public let tolerance: TimeInterval?
            public let runLoop: RunLoop
            public let mode: RunLoop.Mode
            public let options: RunLoop.OCombine.SchedulerOptions?
            
            private var sides = [CombineIdentifier : Side]()
            
            private let lock = UnfairLock.allocate()
            
            /// Creates a publisher that repeatedly emits the current date
            /// on the given interval.
            // 惯例, Publisher 就是为了收集信息.
            public init(
                interval: TimeInterval,
                tolerance: TimeInterval? = nil,
                runLoop: RunLoop,
                mode: RunLoop.Mode,
                options: RunLoop.OCombine.SchedulerOptions? = nil
            ) {
                self.interval = interval
                self.tolerance = tolerance
                self.runLoop = runLoop
                self.mode = mode
                self.options = options
            }
            
            deinit {
                lock.deallocate()
            }
            
            // 对于 downstream 的 attach 请求, 就是存储相关的数据.
            public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
            {
                let inner = Inner(parent: self, downstream: subscriber)
                lock.lock()
                sides[inner.combineIdentifier] = Side(inner)
                lock.unlock()
                subscriber.receive(subscription: inner)
            }
            
            public func connect() -> Cancellable {
                // 直到真正 connect 的时候, 才进行了 timer 的创建.
                let timer = Timer(timeInterval: interval, repeats: true, block: fire)
                timer.tolerance = tolerance ?? 0
                runLoop.add(timer, forMode: mode)
                return CancellableTimer(timer: timer, publisher: self)
            }
            
            // MARK: Private
            
            // 每次定时器触发之后, 进行 downstream 额 send 处理.
            private func fire(_ timer: Timer) {
                lock.lock()
                let sides = self.sides
                lock.unlock()
                let now = Date()
                for side in sides.values {
                    side.send(now)
                }
            }
            
            private func disconnectAll() {
                lock.lock()
                sides = [:]
                lock.unlock()
            }
            
            private func disconnect(_ innerID: CombineIdentifier) {
                lock.lock()
                sides[innerID] = nil
                lock.unlock()
            }
            
            private struct Side {
                let send: (Date) -> Void
                
                init<Downstream: Subscriber>(_ inner: Inner<Downstream>)
                where Downstream.Input == Date, Downstream.Failure == Never
                {
                    send = inner.send
                }
            }
            
            private struct CancellableTimer: Cancellable {
                let timer: Timer
                let publisher: TimerPublisher
                
                func cancel() {
                    publisher.disconnectAll()
                    timer.invalidate()
                }
            }
            
            private final class Inner<Downstream: Subscriber>: Subscription
            where Downstream.Input == Date, Downstream.Failure == Never
            {
                private var downstream: Downstream?
                
                private var pending = Subscribers.Demand.none
                
                private weak var parent: TimerPublisher?
                
                private let lock = UnfairLock.allocate()
                
                init(parent: TimerPublisher, downstream: Downstream) {
                    self.parent = parent
                    self.downstream = downstream
                }
                
                deinit {
                    lock.deallocate()
                }
                
                func send(_ date: Date) {
                    lock.lock()
                    guard let downstream = self.downstream, pending != .none else {
                        lock.unlock()
                        return
                    }
                    pending -= 1
                    lock.unlock()
                    let newDemand = downstream.receive(date)
                    if newDemand == .none {
                        return
                    }
                    lock.lock()
                    pending += newDemand
                    lock.unlock()
                }
                
                func request(_ demand: Subscribers.Demand) {
                    lock.lock()
                    if downstream == nil {
                        lock.unlock()
                        return
                    }
                    pending += demand
                    lock.unlock()
                }
                
                func cancel() {
                    lock.lock()
                    if downstream.take() == nil {
                        lock.unlock()
                        return
                    }
                    lock.unlock()
                    parent?.disconnect(combineIdentifier)
                }
            }
        }
    }
}

#if !canImport(Combine)
extension Foundation.Timer {
    
    /// A publisher that repeatedly emits the current date on a given interval.
    public typealias TimerPublisher = OCombine.TimerPublisher
}
#endif
