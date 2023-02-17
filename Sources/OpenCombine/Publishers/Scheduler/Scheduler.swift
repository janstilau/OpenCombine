/// A protocol that provides to a scheduler with an expression for relative time.
public protocol SchedulerTimeIntervalConvertible {
    
    /// Converts the specified number of seconds into an instance of this scheduler time
    /// type.
    static func seconds(_ s: Int) -> Self
    
    /// Converts the specified number of seconds, as a floating-point value, into
    /// an instance of this scheduler time type.
    static func seconds(_ s: Double) -> Self
    
    /// Converts the specified number of milliseconds into an instance of this scheduler
    /// time type.
    static func milliseconds(_ ms: Int) -> Self
    
    /// Converts the specified number of microseconds into an instance of this scheduler
    /// time type.
    static func microseconds(_ us: Int) -> Self
    
    /// Converts the specified number of nanoseconds into an instance of this scheduler
    /// time type.
    static func nanoseconds(_ ns: Int) -> Self
}
// .delay(for: .seconds(3), scheduler: RunLoop.main, options: .none)

// 调度, 只有两种, 调度环境, 一般就是线程.
// 调度时间, 一般就是延时.

/// A protocol that defines when and how to execute a closure.
// When 就是延时, How 就是线程环境. 目前没想到更多的场景.

/// You can use a scheduler to execute code as soon as possible, or after a future date.
/// Individual scheduler implementations use whatever time-keeping system makes sense for them
// 这里说的很明白, 还是使用系统的各种功能, 来实现调度这件事.

/// Schedulers express this as their `SchedulerTimeType`. Since this type
/// conforms to `SchedulerTimeIntervalConvertible`, you can always express these times
/// with the convenience functions like `.milliseconds(500)`.

// 这个 Option 是泛型的, 每个不同的 SchedulerImp 可以指定自己的 Options
/// Schedulers can accept options to control how they execute the actions passed to them. These options may
/// control factors like which threads or dispatch queues execute the actions.

/*
 /     cancellable = Timer.publish(every: 1.0, on: .main, in: .default)
 /         .autoconnect()
 /         .handleEvents(receiveOutput: { date in
 /             print ("Sending Timestamp \'\(df.string(from: date))\' to delay()")
 /         })
 /         .delay(for: .seconds(3), scheduler: RunLoop.main, options: .none)
 /         .sink(
 /             receiveCompletion: { print ("completion: \($0)", terminator: "\n") },
 /             receiveValue: { value in
 /                 let now = Date()
 /                 print("""
 /                 At \(df.string(from: now)) received Timestamp \
 /                 \'\(df.string(from: value))\' \
 /                 sent: \(String(format: "%.2f", now.timeIntervalSince(value)))
 /                 secs ago
 /                 """)
 /             }
 /         )
 */
public protocol Scheduler {
    
    /// Describes an instant in time for this scheduler.
    associatedtype SchedulerTimeType: Strideable
    where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
    
    /// A type that defines options accepted by the scheduler.
    ///
    /// This type is freely definable by each `Scheduler`. Typically, operations that
    /// take a `Scheduler` parameter will also take `SchedulerOptions`.
    // 
    associatedtype SchedulerOptions
    
    /// This scheduler’s definition of the current moment in time.
    // 每个, 对于 Scheduler, 在实现的时候, 都要定义自己的 time 类型.
    var now: SchedulerTimeType { get }
    
    /// The minimum tolerance allowed by the scheduler.
    // 这个值主要是当做函数调用默认值的. 
    var minimumTolerance: SchedulerTimeType.Stride { get }
    
    /// Performs the action at the next possible opportunity.
    // 最简单的, 就是直接调用 schedule, 在合适的环境, 进行 action 的调用.
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)
    
    /// Performs the action at some time after the specified date.
    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void)
    
    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
}

extension Scheduler {
    
    /// Performs the action at some time after the specified date, using the scheduler’s
    /// minimum tolerance.
    
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: minimumTolerance, action)
    }
    
    /// Performs the action at the next possible opportunity, without options.
    @inlinable
    public func schedule(_ action: @escaping () -> Void) {
        schedule(options: nil, action)
    }
    
    /// Performs the action at some time after the specified date.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: tolerance, options: nil, action)
    }
    
    /// Performs the action at some time after the specified date, at the specified
    /// frequency, taking into account tolerance if possible.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) -> Cancellable {
        return schedule(after: date,
                        interval: interval,
                        tolerance: tolerance,
                        options: nil,
                        action)
    }
    
    /// Performs the action at some time after the specified date, at the specified
    /// frequency, using minimum tolerance possible for this Scheduler.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) -> Cancellable {
        
        return schedule(after: date,
                        interval: interval,
                        tolerance: minimumTolerance,
                        action)
    }
}
