//
//  AnyCancellable.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that
/// makes it possible for a caller to cancel a publisher, but not to use the
/// `Subscription` object to request items.
///
/// An `AnyCancellable` instance automatically calls `cancel()` when deinitialized.

// 这个和 Rx 的相比, 增加了 deinit 的自动调用的机制. 其他的没有太大的变化.

public final class AnyCancellable: Cancellable, Hashable {
    
    private var _cancel: (() -> Void)?
    
    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }
    
    // 这种写法, 会对 canceller 参数进行强引用.
    // 这是一个泛型写法, 而不是一个 Protocol 写法.
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
