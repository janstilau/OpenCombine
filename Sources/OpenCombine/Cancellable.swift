/// A protocol indicating that an activity or action supports cancellation.

/// Calling `cancel()` frees up any allocated resources. It also stops side effects such
/// as timers, network access, or disk I/O.

public protocol Cancellable {
    
    /// Cancel the activity.
    func cancel()
}

extension Cancellable {
    // 为什么, Cancellable 实现对象, 可以使用 RAII 的技术呢.
    // 因为, 真正的装入到容器之前, 使用 AnyCancellable 将他们进行了内存语义的转换.
    // 这种设计, 比 DisposeBag 要优秀. 
    /// Stores this cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `Cancellable`.
    public func store<Cancellables: RangeReplaceableCollection>(
        in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        // 太习惯于使用成员变量来进行引用的方式 .
        // 这种创建一个临时变量装到 Bag 里面的方式应该多多尝试. 
        AnyCancellable(self).store(in: &collection)
    }
    
    /// Stores this cancellable instance in the specified set.
    ///
    /// - Parameter set: The set in which to store this `Cancellable`.
    public func store(in set: inout Set<AnyCancellable>) {
        AnyCancellable(self).store(in: &set)
    }
}
