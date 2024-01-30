
/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that
/// makes it possible for a caller to cancel a publisher, but not to use the
/// `Subscription` object to request items.
///
/// An `AnyCancellable` instance automatically calls `cancel()` when deinitialized.

/// 一种类型擦除的可取消对象，当取消时执行提供的闭包。
///
/// 订阅者的实现可以使用此类型提供“取消标记”，使调用者可以取消发布者，但无法使用 Subscription 对象请求项目。
///
/// AnyCancellable 实例在销毁时会自动调用 cancel()。
public final class AnyCancellable: Cancellable, Hashable {
    
    private var _cancel: (() -> Void)?
    
    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }
    
    public init<OtherCancellable: Cancellable>(_ canceller: OtherCancellable) {
        _cancel = canceller.cancel
    }
    
    public func cancel() {
        _cancel?()
        _cancel = nil
    }
    
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    deinit {
        _cancel?()
    }
}

extension AnyCancellable {
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `AnyCancellable`.
    public func store<Cancellables: RangeReplaceableCollection>(
        in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        collection.append(self)
    }
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `AnyCancellable`.
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}
