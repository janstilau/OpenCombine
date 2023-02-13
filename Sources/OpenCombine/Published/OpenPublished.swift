
/*
 这个非常重要.
 @Published 的属性, 一般会当做 UI 的 Binding 机制存在.
 那么如何引起  @Published 的修改呢.

 使用传统的命令式模式, 将信号和 UI 绑定是一个非常复杂的构成, 并且构建 UI 也是一个繁琐复杂的过程.
 在 ViewModel 的创建过程中, 组合好一个复杂的 Publisher 之后, 将他和 @Published 的 Subject 进行挂钩, 然后, @Published 和 UI 进行挂钩.
 这样, ViewAction, 触发 ModelAction, 然后 ModelAction 触发信号改变. 就能够全部自动了.
 
 Bind 的机制, 就是 ViewAction, 自动触发 Model Action 的过程.
 */
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
    public func assign(to published: inout OpenPublished<Output>.PublishedPublisher) {
        subscribe(PublishedSubscriber(published.internalSubject))
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

/// When the property changes, publishing occurs in the property's `willSet` block,
/// meaning subscribers receive the new value before it's actually set on the property.
/// In the above example, the second time the sink executes its closure, it receives
/// the parameter value `25`. However, if the closure evaluated `weather.temperature`,
/// the value returned would be `20`.
///

// 非常重要的一个 PropertyWrapper
@propertyWrapper
public struct OpenPublished<Value> {
    
    // 专门建立了一个 Publisher 的类型. 可以看到, 真正的实现, 是里面藏了一个 Subject 实现的.
    /*
     一个值语义的对象里面, 是一个引用值.
     对外暴露的是这个值语义的对象.
     但是因为这里面是一个引用值, 所以数据的改变是共享的.
     */
    public struct PublishedPublisher: OpenCombine.Publisher {
        
        public typealias Output = Value
        
        public typealias Failure = Never
        
        // @Published 的真正信号发送, 要依靠内部的一个 PublishedSubject 对象来实现.
        // 这是一个引用值.
        fileprivate let internalSubject: PublishedSubject<Value>
        
        // Publisher 的首先, 接收到后续节点, 移交给了 internalSubject
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
        {
            internalSubject.subscribe(subscriber)
        }
        
        // 在赋初值的时候, 进行了 subject 的构造.
        fileprivate init(_ output: Output) {
            internalSubject = .init(output)
        }
    }
    
    private enum Storage {
        case value(Value)
        case publisher(PublishedPublisher)
    }
    
    // 这个类的唯一作用, 就是把 Storage 的含义, 从值语义变为了引用语义了.
    // 这应该是一个通用类. 任何想要从值语义, 变为引用语义的, 都可以使用一个 Box 类实现这个需求.
    // propertyWrapper 其实也可以是 class, 他会调用对应的构造方法来进行初始化的.
    @propertyWrapper
    private final class PublishedBox {
        var wrappedValue: Storage
        init(wrappedValue: Storage) {
            self.wrappedValue = wrappedValue
        }
    }

    // 这个 Box 并不是凭空出现的, 它的主要作用, 就是把值装到了一个引用类型里面.
    @PublishedBox private var storage: Storage
    
    internal var _objectWillChange: ObservableObjectPublisher? {
        get {
            switch storage {
            case .value:
                return nil
            case .publisher(let publisher):
                return publisher.internalSubject.objectWillChange
            }
        }
        nonmutating set {
            getPublisher().internalSubject.objectWillChange = newValue
        }
    }
    
    public init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }
    
    public init(wrappedValue: Value) {
        // 最初的是简单的 Value 的存储, 并没有 Publisher 的责任在.
        _storage = PublishedBox(wrappedValue: .value(wrappedValue))
    }
    
    /// The property for which this instance exposes a publisher.
    ///
    /// The `projectedValue` is the property accessed with the `$` operator.
    public var projectedValue: PublishedPublisher {
        mutating get {
            return getPublisher()
        }
        
        // 不应该有 Set 存在才对.
        set { // swiftlint:disable:this unused_setter_value
            switch storage {
            case .value(let value):
                storage = .publisher(PublishedPublisher(value))
            case .publisher:
                break
            }
        }
    }
    
    // 一个带有副作用的 Get 方法, 将原本存储, 从值语义, 变为了引用语义.
    // 如果自己实现, 直接就是 .Publisher 的这种情形.
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
    
    // 这是什么意思.
    // swiftlint:disable let_var_whitespace
    @available(*, unavailable, message: """
               @Published is only available on properties of classes
               """)
    // 这是使用 wrappedValue 有什么问题???
    // get 使用 storage 中的 subject value 来获取值.
    // set 使用 storage 中的 subject send 来发送信号.
    // 下面的 subscript 实现过于复杂, 到最后还是找到 storage, 进行 value 的 get, 和信号的 send.
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() } // swiftlint:disable:this unused_setter_value
    }
    
    // swiftlint:enable let_var_whitespace
    // 这里原理不是很清楚, 不过, 给 @Publihsed 属性进行赋值的时候, 就会走到这里.
    // 这里的泛型, 只有一种限制, 那就死 object 要是一个引用值.
    public static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, OpenPublished<Value>>
    ) -> Value {
        // object[keyPath: storageKeyPath] 的结果, 就是一个 @Published 对象.
        get {
            switch object[keyPath: storageKeyPath].storage {
            case .value(let value):
                return value
            case .publisher(let publisher):
                return publisher.internalSubject.value
            }
        }
        
        set {
            // 每次赋值, 都会触发内部真正的 Subject 对象, 相关信号的发射.
            switch object[keyPath: storageKeyPath].storage {
            case .value:
                object[keyPath: storageKeyPath].storage = .publisher(PublishedPublisher(newValue))
            case .publisher(let publisher):
                // 这是是真正的触发信号发送的地方.
                publisher.internalSubject.value = newValue
            }
        }
    }
}
