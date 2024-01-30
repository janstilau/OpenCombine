//
//  Scheduler.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A protocol that provides a scheduler with an expression for relative time.
// 无论怎么定义这个时间节点, 都需要能够使用现有的一套来快速的生成.
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

/// A protocol that defines when and how to execute a closure.
///
/// You can use a scheduler to execute code as soon as possible, or after a future date.
/// Individual scheduler implementations use whatever time-keeping system makes sense
/// for them. Schedulers express this as their `SchedulerTimeType`. Since this type
/// conforms to `SchedulerTimeIntervalConvertible`, you can always express these times
/// with the convenience functions like `.milliseconds(500)`. Schedulers can accept
/// options to control how they execute the actions passed to them. These options may
/// control factors like which threads or dispatch queues execute the actions.
///
/// 一个定义了何时以及如何执行闭包的协议。
///
/// 您可以使用调度器尽快执行代码，或在将来的某个日期之后执行代码。
/// 各个调度器实现使用适合它们的时间跟踪系统来表示这一点，表达为它们的 `SchedulerTimeType`。
/// 由于这个类型符合 `SchedulerTimeIntervalConvertible`，您可以始终使用诸如 `.milliseconds(500)` 之类的便捷函数来表示这些时间。
/// 调度器可以接受选项来控制它们执行传递给它们的操作的方式。
/// 这些选项可能控制诸如哪个线程或调度队列执行操作之类的因素。
public protocol Scheduler {

    /// Describes an instant in time for this scheduler.
    associatedtype SchedulerTimeType: Strideable
        where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible

    /// A type that defines options accepted by the scheduler.
    ///
    /// This type is freely definable by each `Scheduler`. Typically, operations that
    /// take a `Scheduler` parameter will also take `SchedulerOptions`.
    associatedtype SchedulerOptions

    /// This scheduler’s definition of the current moment in time.
    var now: SchedulerTimeType { get }

    /// The minimum tolerance allowed by the scheduler.
    var minimumTolerance: SchedulerTimeType.Stride { get }

    /// Performs the action at the next possible opportunity.
    /// 调度, 但是没有时间的配置.
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date.
    ///  单次调用
    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    /// 多次重复调用
    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
}

extension Scheduler {

    /// Performs the action at some time after the specified date, using the scheduler’s
    /// minimum tolerance.
    ///
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
