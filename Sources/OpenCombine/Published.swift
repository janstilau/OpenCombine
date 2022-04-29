
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
    public func assign(to published: inout Published<Output>.PublishedPublisher) {
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
/*
 苹果文档.
 Publishing a property with the @Published attribute creates a publisher of this type. You access the publisher with the $ operator, as shown here:
 class Weather {
 @Published var temperature: Double
 init(temperature: Double) {
 self.temperature = temperature
 }
 }
 
 let weather = Weather(temperature: 20)
 cancellable = weather.$temperature
 .sink() {
 print ("Temperature now: \($0)")
 }
 weather.temperature = 25
 
 // Prints:
 // Temperature now: 20.0
 // Temperature now: 25.0
 When the property changes, publishing occurs in the property’s willSet block, meaning subscribers receive the new value before it’s actually set on the property. In the above example, the second time the sink executes its closure, it receives the parameter value 25. However, if the closure evaluated weather.temperature, the value returned would be 20.
 */

// 非常重要的一个 PropertyWrapper


@propertyWrapper
public struct Published<Value> {
    
    // 专门建立了一个 Publisher 的类型. 可以看到, 真正的实现, 是里面藏了一个 Subject 实现的.
    public struct PublishedPublisher: OpenCombine.Publisher {
        
        public typealias Output = Value
        
        public typealias Failure = Never
        
        // 实际上, 被 @Published 修饰的属性. 是需要 PublishedSubject 来进行真正实现的.
        fileprivate let subject: PublishedSubject<Value>
        
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
        case publisher(PublishedPublisher)
    }
    
    @propertyWrapper
    private final class PublishedBox {
        var wrappedValue: Storage
        init(wrappedValue: Storage) {
            self.wrappedValue = wrappedValue
        }
    }
    
    // 没太明白, 这里整个 @propertyWrapper 有什么作用. 直接使用 PublishedBox 不得了.
    // 猜测. 使用的时候, storage 更显式. 但是, 需要一个引用语义的对象在这里.
    // 所以, 这个 Box 的唯一的作用, 就是让我们使用 Enum 的同时, 保证了引用语义.
    @PublishedBox private var storage: Storage
    
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
    
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }
    
    public init(wrappedValue: Value) {
        _storage = PublishedBox(wrappedValue: .value(wrappedValue))
    }
    
    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: PublishedPublisher {
        mutating get {
            return getPublisher()
        }
        set { // swiftlint:disable:this unused_setter_value
            switch storage {
            case .value(let value):
                storage = .publisher(PublishedPublisher(value))
            case .publisher:
                break
            }
        }
    }
    
    /// Note: This method can mutate `storage`
    internal func getPublisher() -> PublishedPublisher {
        switch storage {
        case .value(let value):
            // Get 方法里面, 有了副作用.
            // 进行了 Storage 的切换
            let publisher = PublishedPublisher(value)
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
                object[keyPath: storageKeyPath].storage = .publisher(PublishedPublisher(newValue))
            case .publisher(let publisher):
                publisher.subject.value = newValue
            }
        }
    }
}
