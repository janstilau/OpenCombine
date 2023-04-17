/// A type-erasing cancellable object that executes a provided closure when canceled.

/// Subscriber implementations can use this type to provide a “cancellation token” that
/// makes it possible for a caller to cancel a publisher, but not to use the
/// `Subscription` object to request items.

/// An `AnyCancellable` instance automatically calls `cancel()` when deinitialized.
// 这是最最重要的, 将 cancel 这件事和对象的生命周期绑定在了一起.

// AnyCancellable 是一个引用数据类型.

/*
 这种, Any 基本上都有一个同样的实现思路
 1. 这是一个引用类型.
 2. 里面藏着一个闭包, 当 Any 要符合协议的要求的时候, 就是调用这个闭包
 3. init 方法里面, 接受一个 AnyFunc 的 Func 类型的对象. 初始化自己的闭包.
 */

// 这是一个引用类型.
public final class AnyCancellable: Cancellable, Hashable {
    
    // Any 的核心, 就是这样的一个可以自定义的闭包.
    // 各种 Any 都是通过这种方式实现的.
    private var _cancel: (() -> Void)?
    
    /// Initializes the cancellable object with the given cancel-time closure.
    ///
    /// - Parameter cancel: A closure that the `cancel()` method executes.
    public init(_ cancel: @escaping () -> Void) {
        _cancel = cancel
    }
    
    // 各种 Any, 都有着这样的一个实现方式.
    // 但是实际上, 传递过来的都会是一个引用类型实现的 Cancellable 对象.
    public init<OtherCancellable: Cancellable>(_ canceller: OtherCancellable) {
        /*
         这个时候, OtherCancellable 还是有着完整的类型信息的.
         但是不重要, AnyCancellable 对外不暴露这些信息, 他需要的就是一个闭包而已. 
         */
        _cancel = canceller.cancel
    }
    
    public func cancel() {
        _cancel?()
        // 主动的将闭包进行置空, 切断引用的资源.
        // 闭包, 也就是一个引用对象.
        _cancel = nil
    }
    
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    // 这是实现 Bag 的基础所在. 在 Deinit 的时候, 自动触发 cancel 函数. 
    deinit {
        // 这里就没有必要调用 _cancel = nil. 内存管理会做这件事.
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
    
    // 这是一个 Bag 的实现. 
    /// Stores this type-erasing cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `AnyCancellable`.
    // Set<AnyCancellable>, 就当做了 disposeBag 来使用了.
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}
