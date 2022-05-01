

/*
 大部分的 Publisher, 都是 struct 值语义的.
 Publisher 的作用, 其实是收集信息. 这些信息, 一般都会在真正生成响应链路的时候, 赋值到 引用类型的 InnerSink 节点中.
 所以, 各种 Operator 的使用, 其实就是一顿值的复制工作.
 到了最后的一个 Operator, 它的 upstream 对象, 其实是一个非常庞大的结构体了. 
 */
extension Publisher {
    
    /// Wraps this publisher with a type eraser.
    
    /// Use `eraseToAnyPublisher()` to expose an instance of `AnyPublisher`` to
    /// the downstream subscriber, rather than this publisher’s actual type.
    
    /// This form of _type erasure_ preserves abstraction across API boundaries, such as
    /// different modules.
    
    /// When you expose your publishers as the `AnyPublisher` type, you can change
    /// the underlying implementation over time without affecting existing clients.
    // 使用, AnyPublisher, 使得暴露的各种类型, 得到了统一.
    
    /// The following example shows two types that each have a `publisher` property.
    /// `TypeWithSubject` exposes this property as its actual type, `PassthroughSubject`,
    /// while `TypeWithErasedSubject` uses `eraseToAnyPublisher()` to expose it as
    /// an `AnyPublisher`. As seen in the output, a caller from another module can access
    /// `TypeWithSubject.publisher` as its native type. This means you can’t change your
    /// publisher to a different type without breaking the caller.
    // 这里的问题是, 只要返回值的类型暴露出去了, 使用者就可能使用该类型去做一些事情. 为什么要面向抽象编程, 其实也是这一层含义. 使用者, 本来应该仅仅使用抽象调用相关的方法, 但是因为暴露出了太多的东西, 使得后续修改, 无法替换.
    
    /// By comparison, `TypeWithErasedSubject.publisher` appears to callers as an `AnyPublisher`, so you
    /// can change the underlying publisher type at will.
    ///
    ///     public class TypeWithSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int,Never>()
    ///     }
    ///     public class TypeWithErasedSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int,Never>()
    ///             .eraseToAnyPublisher()
    ///     }
    ///
    ///     // In another module:
    ///     let nonErased = TypeWithSubject()
    ///     if let subject = nonErased.publisher as? PassthroughSubject<Int,Never> {
    ///         print("Successfully cast nonErased.publisher.")
    ///     }
    ///     let erased = TypeWithErasedSubject()
    ///     if let subject = erased.publisher as? PassthroughSubject<Int,Never> {
    ///         print("Successfully cast erased.publisher.")
    ///     }
    ///
    ///     // Prints "Successfully cast nonErased.publisher."
    ///
    /// - Returns: An ``AnyPublisher`` wrapping this publisher.
    
    // 固定套路.
    // 在 Publisher 上, 增加一个快捷方法, 用来生成真正的 Operator 对象.
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        return .init(self)
    }
}

/// A type-erasing publisher.
///
/// Use `AnyPublisher` to wrap a publisher whose type has details you don’t want to expose
/// across API boundaries, such as different modules. Wrapping a `Subject` with
/// `AnyPublisher` also prevents callers from accessing its `send(_:)` method. When you
/// use type erasure this way, you can change the underlying publisher implementation over
/// time without affecting existing clients.
///
/// You can use OpenCombine’s `eraseToAnyPublisher()` operator to wrap a publisher with
/// `AnyPublisher`.

// 这还是一个值语义的结构, 但是, 里面有一个引用语义的 Box.
// 真实一位这个引用语义的 Box, 使得这个对象, 其实是一个引用语义的结构.
public struct AnyPublisher<Output, Failure: Error>
: CustomStringConvertible,
  CustomPlaygroundDisplayConvertible {
    
    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>
    
    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameter publisher: A publisher to wrap with a type-eraser.
    // 如果, 这里是一个接口对象, 会有什么问题???
    // 重点. Publisher 这个 Protocol, 是无法单独作为参数的类型修饰的, 因为它有  .
    // 拥有 associatedtype 的协议, 代表着, 这个协议的类型是不完整的. 它只能在泛型中作为类型参数的限制使用.
    // 因为泛型方法, 在真正被调用的时候, 必须是能够确定类型, 才能保证编译通过, 那么 Protocol 里面的 associatedtype 的类型也就能够确认了.
    // 所以, 这里只能使用泛型的方式.
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType)
    where Output == PublisherType.Output, Failure == PublisherType.Failure
    {
        // If this has already been boxed, avoid boxing again
        if let erased = publisher as? AnyPublisher<Output, Failure> {
            box = erased.box
        } else {
            box = PublisherBox(base: publisher)
        }
    }
    
    public var description: String {
        return "AnyPublisher"
    }
    
    public var playgroundDescription: Any {
        return description
    }
}

extension AnyPublisher: Publisher {
    
    /// This function is called to attach the specified `Subscriber` to this `Publisher`
    /// by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    @inlinable
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        box.receive(subscriber: subscriber)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
@usableFromInline
internal class PublisherBoxBase<Output, Failure: Error>: Publisher {
    
    @inlinable
    internal init() {}
    
    @usableFromInline
    internal func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Failure == Downstream.Failure, Output == Downstream.Input
    {
        abstractMethod()
    }
}

// 这种, Box, BoxBase 的结构非常常见. 是一种设计模式??? 为了之后可以灵活替换???
// 看起来, 像是模板方法.
@usableFromInline
internal final class PublisherBox<PublisherType: Publisher>
: PublisherBoxBase<PublisherType.Output, PublisherType.Failure>
{
    // 相比较, 存储 Block 的方式, 这种显式的存储一个抽象数据在内部的做法, 是不是更加的清晰一点.
    @usableFromInline
    internal let base: PublisherType
    
    @inlinable
    internal init(base: PublisherType) {
        self.base = base
        super.init()
    }
    
    @inlinable
    override internal func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Failure == Downstream.Failure, Output == Downstream.Input
    {
        base.receive(subscriber: subscriber)
    }
}
