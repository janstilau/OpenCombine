
/// A protocol that provides to a scheduler with an expression for relative time.
// SchedulerTimeType 是每种 Scheduler 的时间单位, 它的要求是 Strideable. 也就是, 知道了一个位置之后, 可以快速的根据计量单位, 来计算出下一个为孩子.
// SchedulerTimeType.Strde 的每种 Scheduler 的时间计量单位, 它的要求是 SchedulerTimeIntervalConvertible. 也就是, 可以通过下面的, 具有人类识别语言定义的各个接口, 来获取计量对象出来.
// 例如, 如果按照中国传统 12 时辰的方法计时, 那么 SchedulerTimeType 就是各种 xx时, 而 SchedulerTimeType.Strde 就是刻. 刻这种计量单位, 应该提供下面各种秒相关的换算方法.
// 在真正 scheduler 被使用的时候, 是使用的下面 SchedulerTimeIntervalConvertible 的统一的接口.

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
/*
 上面的 Delay 的用法, 是 scheduler 的实际用法.
 这个类型, 其实并不是给 Combine 的使用者使用的, 而是给 Operator 的设计者来使用的.
 Operator 首先会保存一个 Scheduler 的实例. 这是 Operator 对应的 Publisher 方法里面传递过来的.
 SchedulerOptions, 和 SchedulerTimeType 是和传递过来的 Scheduler 实例强绑定的, 当调用相关方法的时候, 在传入对应 Scheduler 实例的时候, 其他的参数, 就应该锁定到相关的 associatedtype 了.
 这体现了泛型编程的类型锁定的用途. 这个时候, 也体现了面向接口的好处, 因为 SchedulerTimeIntervalConvertible 的限定, 使得各个 Scheduler 相关的 SchedulerTimeType.Stride 参数在使用的时候, 可以使用上面的 seconds, millionseconds 方法, 这样使得该参数的使用, 是一个统一的方式.
 在 Operator 的内部逻辑里面,
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
