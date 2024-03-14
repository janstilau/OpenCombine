//
//  Published.swift
//  OpenCombine
//
//  Created by Евгений Богомолов on 01/09/2019.
//

#if swift(>=5.1)

extension Publisher where Failure == Never {
    
    /// Republishes elements received from a publisher, by assigning them to a property
    /// marked as a publisher.
    ///
    /// Use this operator when you want to receive elements from a publisher and republish
    /// them through a property marked with the `@Published` attribute. The `assign(to:)`
    /// operator manages the life cycle of the subscription, canceling the subscription
    /// automatically when the `Published` instance deinitializes. Because of this,
    /// the `assign(to:)` operator doesn't return an `AnyCancellable` that you're
    /// responsible for like `assign(to:on:)` does.
    ///
    /// The example below shows a model class that receives elements from an internal
    /// `Timer.TimerPublisher`, and assigns them to a `@Published` property called
    /// `lastUpdated`:
    ///
    ///     class MyModel: ObservableObject {
    ///             @Published var lastUpdated: Date = Date()
    ///             init() {
    ///                  Timer.publish(every: 1.0, on: .main, in: .common)
    ///                      .autoconnect()
    ///                      .assign(to: $lastUpdated)
    ///             }
    ///         }
    ///
    /// If you instead implemented `MyModel` with `assign(to: lastUpdated, on: self)`,
    /// storing the returned `AnyCancellable` instance could cause a reference cycle,
    /// because the `Subscribers.Assign` subscriber would hold a strong reference
    /// to `self`. Using `assign(to:)` solves this problem.
    ///
    /// - Parameter published: A property marked with the `@Published` attribute, which
    ///   receives and republishes all elements received from the upstream publisher.
    
    /// 通过将元素分配给被标记为发布者的属性，重新发布从发布者接收的元素。
    ///
    /// 当你想要从一个发布者接收元素并通过标有 `@Published` 属性的属性重新发布它们时，使用这个操作符。`assign(to:)` 操作符管理订阅的生命周期，在 `Published` 实例解初始化时自动取消订阅。因此，`assign(to:)` 操作符不像 `assign(to:on:)` 那样返回一个你需要负责的 `AnyCancellable`。
    ///
    /// 下面的示例展示了一个模型类，它从内部的 `Timer.TimerPublisher` 接收元素，并将它们分配给一个名为 `lastUpdated` 的 `@Published` 属性：
    ///
    /// ```swift
    /// class MyModel: ObservableObject {
    ///     @Published var lastUpdated: Date = Date()
    ///
    ///     init() {
    ///         Timer.publish(every: 1.0, on: .main, in: .common)
    ///             .autoconnect()
    ///             .assign(to: $lastUpdated)
    ///     }
    /// }
    /// ```
    ///
    /// 如果你用 `assign(to: lastUpdated, on: self)` 来实现 `MyModel`，存储返回的 `AnyCancellable` 实例可能导致引用循环，因为 `Subscribers.Assign` 订阅者会持有对 `self` 的强引用。使用 `assign(to:)` 可以解决这个问题。
    ///
    /// - Parameter published: 一个被标记为 `@Published` 属性的属性，它接收并重新发布从上游发布者接收的所有元素。
    public func assign(to published: inout Published<Output>.Publisher) {
        subscribe(PublishedSubscriber(published.subject))
    }
}

/// A type that publishes a property marked with an attribute.
///
/// Publishing a property with the `@Published` attribute creates a publisher of this
/// type. You access the publisher with the `$` operator, as shown here:
///
///     class Weather {
///         @Published var temperature: Double
///         init(temperature: Double) {
///             self.temperature = temperature
///         }
///     }
///
///     let weather = Weather(temperature: 20)
///     cancellable = weather.$temperature
///         .sink() {
///             print ("Temperature now: \($0)")
///         }
///     weather.temperature = 25
///
///     // Prints:
///     // Temperature now: 20.0
///     // Temperature now: 25.0
///
/// When the property changes, publishing occurs in the property's `willSet` block,
/// meaning subscribers receive the new value before it's actually set on the property.
/// In the above example, the second time the sink executes its closure, it receives
/// the parameter value `25`. However, if the closure evaluated `weather.temperature`,
/// the value returned would be `20`.
///
/// > Important: The `@Published` attribute is class constrained. Use it with properties
/// of classes, not with non-class types like structures.
///
/// ### See Also
///
/// - `Publisher.assign(to:)`

/// 一种发布带有属性标记的类型。
///
/// 使用 `@Published` 属性标记发布属性将创建此类型的发布者。你可以使用 `$` 操作符访问该发布者，如下所示：
/// 从这里可以看出, 这个属性的内部, 其实是创建了一个发布者在.
///
/// ```swift
/// class Weather {
///     @Published var temperature: Double
///     init(temperature: Double) {
///         self.temperature = temperature
///     }
/// }
///
/// let weather = Weather(temperature: 20)
/// cancellable = weather.$temperature
///     .sink() {
///         print("当前温度: \($0)")
///     }
/// weather.temperature = 25
///
/// // 打印:
/// // 当前温度: 20.0
/// // 当前温度: 25.0
/// ```
///
/// 原来这 Publisher, 会是在真正设置值之前, 发出去. 
/// 当属性发生变化时，在属性的 `willSet` 块中进行发布，这意味着订阅者在实际设置属性之前接收到新值。在上面的例子中，第二次 `sink` 执行其闭包时，它接收到参数值 `25`。但是，如果闭包评估 `weather.temperature`，返回的值将是 `20`。
///
/// > 重要提示: `@Published` 属性是类约束的。请将其与类的属性一起使用，而不是与结构等非类类型一起使用。
///
/// ### 另请参阅
///
/// - `Publisher.assign(to:)`

@available(swift, introduced: 5.1)
@propertyWrapper
public struct Published<Value> {
    
    /// A publisher for properties marked with the `@Published` attribute.
    // 在 Published 这个 Wrapper 的内部, 其实是存储了一个 Publisher.
    public struct Publisher: OpenCombine.Publisher {
        
        public typealias Output = Value
        
        public typealias Failure = Never
        
        fileprivate let subject: PublishedSubject<Value>
        
        /*
         在这个 Publihser 里面, 她不是一个工程, 而是里面存储了一个 Subject 的对象. 然后, 每次有下游的时候, 其实是把这个下游, 添加到了这个 Subject 对象上面.
         */
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
        {
            subject.subscribe(subscriber)
        }
        
        fileprivate init(_ output: Output) {
            subject = .init(output)
        }
    }
    
    private enum Storage {
        case value(Value)
        case publisher(Publisher)
    }
    
    @propertyWrapper
    private final class Box {
        var wrappedValue: Storage
        
        init(wrappedValue: Storage) {
            self.wrappedValue = wrappedValue
        }
    }
    
    /*
     Published 是一个结构体.
     但是里面存储的, 是一个引用值, Box
     Box 里面存储的是一个 Enum
     Enum 里面有两种状态.
     1. Value 的值.
     2. PublishedSubject 对象, 这是一个引用值, 里面会存储 Value 值.
     
     因为 Box 是一个引用值, 所以, 在进行拷贝的时候, 其实所有的 Published 的, 都会有一个 Publisher.
     */
    @Box private var storage: Storage
    
    // 这个一点作用都没有发生.
    // 这是 Internal 的一个值, 外界是没有办法使用的.
    internal var objectWillChange: ObservableObjectPublisher? {
        get {
            switch storage {
            case .value:
                return nil
            case .publisher(let publisher):
                return publisher.subject.objectWillChange
            }
        }
        nonmutating set {
            getPublisher().subject.objectWillChange = newValue
        }
    }
    
    /// Creates the published instance with an initial wrapped value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Published` attribute, as shown here:
    ///
    ///     @Published var lastUpdated: Date = Date()
    ///
    /// - Parameter wrappedValue: The publisher's initial value.
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }
    
    /// Creates the published instance with an initial value.
    ///
    /// Don't use this initializer directly. Instead, create a property with
    /// the `@Published` attribute, as shown here:
    ///
    ///     @Published var lastUpdated: Date = Date()
    ///
    /// - Parameter initialValue: The publisher's initial value.
    public init(wrappedValue: Value) {
        // 使用 propertyWrapper 修饰的对象, 其实会有一个 _ 开头的真正的属性.
        _storage = Box(wrappedValue: .value(wrappedValue))
    }
    
    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: Publisher {
        mutating get {
            // get 里面, 可能会修改自己的值, 所以使用 mutating 进行了修饰.
            return getPublisher()
        }
        set { // swiftlint:disable:this unused_setter_value
            // 其实是无法进行赋值的. 这里根本没有使用到 newValue.
            switch storage {
            case .value(let value):
                storage = .publisher(Publisher(value))
            case .publisher:
                break
            }
        }
    }
    
    /// Note: This method can mutate `storage`
    /// 这个方法, 其实有着副作用的. 
    internal func getPublisher() -> Publisher {
        switch storage {
        case .value(let value):
            let publisher = Publisher(value)
            storage = .publisher(publisher)
            return publisher
        case .publisher(let publisher):
            return publisher
        }
    }
    // swiftlint:disable let_var_whitespace
    @available(*, unavailable, message: """
               @Published is only available on properties of classes
               """)
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() } // swiftlint:disable:this unused_setter_value
    }
    // swiftlint:enable let_var_whitespace
    
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Published<Value>>
    ) -> Value {
        get {
            switch object[keyPath: storageKeyPath].storage {
            case .value(let value):
                return value
            case .publisher(let publisher):
                return publisher.subject.value
            }
        }
        set {
            switch object[keyPath: storageKeyPath].storage {
            case .value:
                object[keyPath: storageKeyPath].storage = .publisher(Publisher(newValue))
            case .publisher(let publisher):
                // 这里才是, 修改 wrapper 的值, 触发修改的原因所在.
                publisher.subject.value = newValue
            }
        }
        // TODO: Benchmark and explore a possibility to use _modify
    }
}
#else

@available(swift, introduced: 5.1)
public typealias Published = Never

#endif // swift(>=5.1)

