
/// A type-erasing cancellable object that executes a provided closure when canceled.
///
/// Subscriber implementations can use this type to provide a “cancellation token” that
/// makes it possible for a caller to cancel a publisher, but not to use the
/// `Subscription` object to request items.
///
/// An `AnyCancellable` instance automatically calls `cancel()` when deinitialized.

// 这个和 Rx 的相比, 增加了 deinit 的自动调用的机制. 其他的没有太大的变化.
// AnyCancellable 是一个引用数据类型.

/*
 这种, Any 基本上都有一个同样的实现思路
 1. 这是一个引用类型.
 2. 里面藏着一个闭包, 当 Any 要符合协议的要求的时候, 就是调用这个闭包
 3. init 方法里面, 接受一个 AnyFunc 的 Func 类型的对象. 初始化自己的闭包, 是这个 Func 对象.func. Func 对象, 可以是引用语义的, 也可以是值语义的.
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
    public init<OtherCancellable: Cancellable>(_ canceller: OtherCancellable) {
        /*
         Cancellable 可不是一个 class protocol.
         如果, 是一个引用对象传递过来了, 那么 canceller.cancel, 这个闭包会引用到 canceller 的值. 所以, 会有该对象的强引用.
         如果, 是一个值对象传递过来了, 那么 canceller.cancel, 这个闭包会把这个值对象里面的值都复制一遍到闭包中. 如果, 该值对象里面有一个引用值, 会有对于那个引用值的循环引用.
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
    
    /// Stores this type-erasing cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `AnyCancellable`.
    // Set<AnyCancellable>, 就当做了 disposeBag 来使用了. 
    public func store(in set: inout Set<AnyCancellable>) {
        set.insert(self)
    }
}
