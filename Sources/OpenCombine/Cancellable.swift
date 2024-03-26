/// A protocol indicating that an activity or action supports cancellation.
///
/// Calling `cancel()` frees up any allocated resources. It also stops side effects such
/// as timers, network access, or disk I/O.

public protocol Cancellable {

    /// Cancel the activity.
    func cancel()
}

// 使用了 AnyCancellable, 将自己变为了一个引用类型, 并且在 AnyCancellable 中, 触发了 cancel 的动作. 
extension Cancellable {
    /// Stores this cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `Cancellable`.
    public func store<Cancellables: RangeReplaceableCollection>(
            in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        AnyCancellable(self).store(in: &collection)
    }

    /// Stores this cancellable instance in the specified set.
    ///
    /// - Parameter set: The set in which to store this `Cancellable`.
    public func store(in set: inout Set<AnyCancellable>) {
        AnyCancellable(self).store(in: &set)
    }
}
