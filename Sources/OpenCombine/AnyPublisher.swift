
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
    ///
    ///     let erased = TypeWithErasedSubject()
    ///     if let subject = erased.publisher as? PassthroughSubject<Int,Never> {
    ///         print("Successfully cast erased.publisher.")
    ///     }
    ///
    ///     // Prints "Successfully cast nonErased.publisher."
    /// - Returns: An ``AnyPublisher`` wrapping this publisher.
    // 之所以, 出现上面的状况是, AnyPublisher 是一个包装类型. 他和被包装的类型, 是没有类型关系的.
    
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        return .init(self)
    }
}

/// A type-erasing publisher.

/// Use `AnyPublisher` to wrap a publisher whose type has details you don’t want to expose
/// across API boundaries, such as different modules. Wrapping a `Subject` with
/// `AnyPublisher` also prevents callers from accessing its `send(_:)` method. When you
/// use type erasure this way, you can change the underlying publisher implementation over
/// time without affecting existing clients.

/// You can use OpenCombine’s `eraseToAnyPublisher()` operator to wrap a publisher with
/// `AnyPublisher`.

/*
 public struct Map<Upstream: Publisher, Output>: Publisher
 上面是 Map 的结构. 因为, 它的 Upstream 类型参数是一个 Publisher. 所以, 当多次进行 map 之后, 里面的类型就会变得异常复杂.
 AnyPublisher 就是为了解决这个问题的, 它的类型参数, 重新变为了最最原始的 Output, Failure 的形式, 他所 box 住的 Publisher 的相关信息, 完全进行了隐藏 .
 */
public struct AnyPublisher<Output, Failure: Error>
: CustomStringConvertible,
  CustomPlaygroundDisplayConvertible {
    
    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>
    
    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameter publisher: A publisher to wrap with a type-eraser.
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType)
    where Output == PublisherType.Output, Failure == PublisherType.Failure
    {
        // 使用一个接口对象来完成对于 Publisher 协议的实现.
        // 然后这个接口对象, 到底如何生成其实是在内部完成的.
        // 在类的内部, 都是使用 box 的抽象接口完成的功能逻辑.
        // 在这个类里面, 没有太多的体现, 在 Subscriber 里面, 在内部使用 box, box 可能是不同的类型对象.
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

// AnyPublisher 对于 Publisher 的实现, 完全转交给了自己存储的 Box 对象了. 而这个对象, 是一个抽象数据类型.
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

/*
 PublisherBox 的生成, 是需要完成的类型信息的.
 在 AnyPublisher 的 init 方法里面, 参数是需要完整的类型信息的.
 这些完整的类型信息中的类型, 被抽取出来, 来填充 PublisherBoxBase 所需要的类型信息.
 AnyPublisher 中所暴露出去的, 也是这些被抽取的类型信息.
 通过这样, 完整的类型被隐藏了, 仅仅暴露出完整的类型信息中的部分信息.
 */
@usableFromInline
internal final class PublisherBox<PublisherType: Publisher>
: PublisherBoxBase<PublisherType.Output, PublisherType.Failure>
{
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
