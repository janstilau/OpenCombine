extension Publisher {
    
    /// Wraps this publisher with a type eraser.
    ///
    /// Use `eraseToAnyPublisher()` to expose an instance of `AnyPublisher`` to
    /// the downstream subscriber, rather than this publisher’s actual type.
    
    /// This form of _type erasure_ preserves abstraction across API boundaries, such as
    /// different modules.
    /// When you expose your publishers as the `AnyPublisher` type, you can change
    /// the underlying implementation over time without affecting existing clients.
    
    /// The following example shows two types that each have a `publisher` property.
    /// `TypeWithSubject` exposes this property as its actual type, `PassthroughSubject`,
    /// while `TypeWithErasedSubject` uses `eraseToAnyPublisher()` to expose it as
    /// an `AnyPublisher`. As seen in the output, a caller from another module can access
    /// `TypeWithSubject.publisher` as its native type. This means you can’t change your
    /// publisher to a different type without breaking the caller. By comparison,
    /// `TypeWithErasedSubject.publisher` appears to callers as an `AnyPublisher`, so you
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
    
    /// 使用类型擦除器包装此发布者。
    ///
    /// 使用 `eraseToAnyPublisher()` 将实例暴露为 `AnyPublisher`，而不是此发布者的实际类型。
    /// 这种形式的 _类型擦除_ 通过 API 边界（例如不同的模块）保留了抽象。
    /// 当将发布者暴露为 `AnyPublisher` 类型时，您可以随时更改底层实现而不影响现有的客户端。
    ///
    /// 以下示例显示了两种类型，每种类型都有一个 `publisher` 属性。
    /// `TypeWithSubject` 将此属性公开为其实际类型 `PassthroughSubject`，
    /// 而 `TypeWithErasedSubject` 使用 `eraseToAnyPublisher()` 将其公开为
    /// `AnyPublisher`。如输出中所示，来自另一个模块的调用者可以访问
    /// `TypeWithSubject.publisher` 作为其本机类型。这意味着您不能更改
    /// 发布者为其他类型而不破坏调用者。相比之下，
    /// `TypeWithErasedSubject.publisher` 对调用者呈现为 `AnyPublisher`，
    /// 因此可以随时更改底层发布者类型。
    ///
    ///     public class TypeWithSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int, Never>()
    ///     }
    ///     public class TypeWithErasedSubject {
    ///         public let publisher: some Publisher = PassthroughSubject<Int, Never>()
    ///             .eraseToAnyPublisher()
    ///     }
    ///
    ///     // 在另一个模块中:
    ///     let nonErased = TypeWithSubject()
    ///     if let subject = nonErased.publisher as? PassthroughSubject<Int, Never> {
    ///         print("Successfully cast nonErased.publisher.")
    ///     }
    ///     let erased = TypeWithErasedSubject()
    ///     if let subject = erased.publisher as? PassthroughSubject<Int, Never> {
    ///         print("Successfully cast erased.publisher.")
    ///     }
    ///
    ///     // 打印 "Successfully cast nonErased.publisher."
    ///
    /// - Returns: 包装此发布者的 ``AnyPublisher``。
    @inlinable
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
public struct AnyPublisher<Output, Failure: Error>
: CustomStringConvertible,
  CustomPlaygroundDisplayConvertible
{
    @usableFromInline
    internal let box: PublisherBoxBase<Output, Failure>
    
    /// Creates a type-erasing publisher to wrap the provided publisher.
    ///
    /// - Parameter publisher: A publisher to wrap with a type-eraser.
    // 基本上, 这种 Any 都是一个通用的思路, 就是里面会有一个中间的 box 做真正的类型消除.
    // 也就是说, 它的 Init 方法是泛型的, 里面的 box 数据是泛型的, 然后整体的类型, 则是将真正的 Init 的参数类型进行了消除.
    @inlinable
    public init<PublisherType: Publisher>(_ publisher: PublisherType)
    where Output == PublisherType.Output, Failure == PublisherType.Failure
    {
        // If this has already been boxed, avoid boxing again
        // box 之所以使用引用值, 其实页就是为了这里. 可以直接进行传递.
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
