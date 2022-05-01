
extension Publisher where Failure == Never {
    
    /// Republishes elements received from a publisher, by assigning them to a property
    /// marked as a publisher.
    
    /// Use this operator when you want to receive elements from a publisher and republish
    /// them through a property marked with the `@Published` attribute. The `assign(to:)`
    /// operator manages the life cycle of the subscription, canceling the subscription
    /// automatically when the `Published` instance deinitializes. Because of this,
    /// the `assign(to:)` operator doesn't return an `AnyCancellable` that you're
    /// responsible for like `assign(to:on:)` does.
    // Published 作为 downstream, 是一个弱指针. 当 Published 对象消失之后, 该指针消失, 也就无法向后进行事件的传送了.
    
    /// The example below shows a model class that receives elements from an internal
    /// `Timer.TimerPublisher`, and assigns them to a `@Published` property called
    /// `lastUpdated`:
    
    ///     class MyModel: ObservableObject {
    ///             @Published var lastUpdated: Date = Date()
    ///             init() {
    ///                  Timer.publish(every: 1.0, on: .main, in: .common)
    ///                      .autoconnect()
    ///                      .assign(to: $lastUpdated)
    ///             }
    ///         }
    
    /// If you instead implemented `MyModel` with `assign(to: lastUpdated, on: self)`,
    /// storing the returned `AnyCancellable` instance could cause a reference cycle,
    // AnyCancellable 里面存储的, 就是 Assign 对象, 里面强引用了 self.
    // AnyCancellable 再次被引用, 这就形成了循环引用.
    
    /// because the `Subscribers.Assign` subscriber would hold a strong reference
    /// to `self`. Using `assign(to:)` solves this problem.
    ///
    /// - Parameter published: A property marked with the `@Published` attribute, which
    ///   receives and republishes all elements received from the upstream publisher.
    
    // 上游触发的操作, 可以直接影响到 PublishedPublisher 对象.
    // 这是一个响应链条的终点.
    // 而这个终点之后的触发, 和之前的链条, 没有太大的关系.
    public func assign(to published: inout Published<Output>.PublishedPublisher) {
        subscribe(PublishedSubscriber(published.subject))
    }
}



/// A type that publishes a property marked with an attribute.

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

// 非常重要的一个 PropertyWrapper

@propertyWrapper
public struct Published<Value> {
    
    // 专门建立了一个 Publisher 的类型. 可以看到, 真正的实现, 是里面藏了一个 Subject 实现的.
    public struct PublishedPublisher: OpenCombine.Publisher {
        
        public typealias Output = Value
        
        public typealias Failure = Never
        
        // @Published 的真正信号发送, 要依靠内部的一个 PublishedSubject 对象来实现.
        fileprivate let subject: PublishedSubject<Value>
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
        {
            subject.subscribe(subscriber)
        }
        
        fileprivate init(_ output: Output) {
            // 这种写法, 在第三方类库里面, 非常常见.
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
    
    // 这里实现的有点复杂啊.
    // 如果我实现, 可能里面就一个 PublishedSubject 属性就完事了. 
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
        // 不应该出现在 Set 里面,
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
    
    // 这是什么意思.
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
                // 在这里, 触发了改变.
                publisher.subject.value = newValue
            }
        }
    }
}
