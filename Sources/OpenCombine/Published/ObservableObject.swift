/// A type of object with a publisher that emits before the object has changed.

/// By default an `ObservableObject` synthesizes an `objectWillChange` publisher that
/// emits the changed value before any of its `@Published` properties changes.
// 如果, 标注了是 ObservableObject 对象, 并且里面有 @Published 的属性, 那么每次 @Published 的属性变化之前, 都会引起 objectWillChange 对应的 Publisher 的信号发送
// 也可以自己实现 objectWillChange 的真正实现.

///     class Contact : ObservableObject {
///         @Published var name: String
///         @Published var age: Int
///
///         init(name: String, age: Int) {
///             self.name = name
///             self.age = age
///         }
///
///         func haveBirthday() -> Int {
///             age += 1
///         }
///     }
///
///     let john = Contact(name: "John Appleseed", age: 24)
///     cancellable = john.objectWillChange
///         .sink { _ in
///             print("\(john.age) will change")
///         }
///     print(john.haveBirthday())
///     // Prints "24 will change"
///     // Prints "25"

public protocol ObservableObject: AnyObject {
    
    /// The type of publisher that emits before the object has changed.
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
    where ObjectWillChangePublisher.Failure == Never
    
    /// A publisher that emits before the object has changed.
    var objectWillChange: ObjectWillChangePublisher { get }
}

// 这里是一个小技巧, 专门做一个私有协议, 然后让特定的类型来实现该协议.
// 其实, 就是类型判断. 不过如果类型过多的话, 使用协议判断, 代码会更加的清晰.
private protocol _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

#if swift(>=5.1)
extension Published: _ObservableObjectProperty {}

// ObservableObject 的 objectWillChange 会自动合成. 就是在 get 的时候, 进行了懒加载.
// 并且, 对于每个 Published 属性中, 隐藏的 Publisher 的 objectWillChange 进行了赋值操作.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    
    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {
        var installedPublisher: ObservableObjectPublisher?
        
        // 使用元信息, 查找到 Published 类型. 对里面的值 objectWillChange 属性进行了赋值 .
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {
                // 首先判断, 是否是 Published 的类型.
                guard let property = property as? _ObservableObjectProperty else {
                    // Visit other fields until we meet a @Published field
                    continue
                }
                
                // 然后判断, 是否 Published 类型, 是否已经有了 objectWillChange 属性了.
                // 如果一个有了, 那就是全都有了.
                if let alreadyInstalledPublisher = property.objectWillChange {
                    installedPublisher = alreadyInstalledPublisher
                    // Don't visit other fields, as all @Published fields
                    // already have a publisher installed.
                    break
                }
                
                // 如果 @Published 已经有了 objectWillChange, 那就证明, 这个 ObservableObject 已经初始化过 objectWillChange 属性了. 直接返回.
                // 如果, 还没有, 那么将所有的 @Published 属性的 objectWillChange 统一赋值成为 installedPublisher
                // 正是因为如此, 所有的 @Published 都是使用了同样的一个 Publisher, 才能实现, 每个值修改之前, 都能触发同一个信号的发射.
                // Okay, this field doesn't have a publisher installed.
                // This means that other fields don't have it either
                // (because we install it only once and fields can't be added at runtime).
                var lazilyCreatedPublisher: ObjectWillChangePublisher {
                    if let publisher = installedPublisher {
                        return publisher
                    }
                    let publisher = ObservableObjectPublisher()
                    installedPublisher = publisher
                    return publisher
                }
                // 注意, 这里 lazilyCreatedPublisher 的构建过程.
                // 如果 installedPublisher 有值了, 那么就使用 installedPublisher 的值.
                // 所以, 最终所有的 Property 都是使用的同样的一个 installedPublisher.
                // 真的是令人困恼的代码.
                property.objectWillChange = lazilyCreatedPublisher
                // Continue visiting other fields.
            }
            reflection = aClass.superclassMirror
        }
        
        // 如果, 没有 installedPublisher, 那就是里面根本就没有 @Published 属性. 随便给一个值.
        return installedPublisher ?? ObservableObjectPublisher()
    }
}

#endif

/// A publisher that publishes changes from observable objects.
public final class ObservableObjectPublisher: Publisher {
    
    // 仅仅是, 值发生了改变, 并不告诉当前的值是什么.
    // 系统自动合成的, 也是不告诉你哪个属性发生了变化, 仅仅是该引用类型的属性, 发生了变化.
    public typealias Output = Void
    
    public typealias Failure = Never
    
    private let lock = UnfairLock.allocate()
    
    private var connections = Set<Conduit>()
    
    // TODO: Combine needs this for some reason
    private var identifier: ObjectIdentifier?
    
    /// Creates an observable object publisher instance.
    public init() {}
    
    deinit {
        lock.deallocate()
    }
    
    // 当, 收到了下游节点的 attach 请求之后, 创建了 Inner 对象, 进行管理. 从这里来看, 这个 Publisher 是当成了一个 DisPatch 节点来使用了.
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Void, Downstream.Failure == Never {
        let inner = Inner(downstream: subscriber, parent: self)
        lock.lock()
        connections.insert(inner)
        lock.unlock()
        subscriber.receive(subscription: inner)
    }
    
    public func send() {
        lock.lock()
        let connections = self.connections
        lock.unlock()
        for connection in connections {
            connection.send()
        }
    }
    
    private func remove(_ conduit: Conduit) {
        lock.lock()
        connections.remove(conduit)
        lock.unlock()
    }
}

extension ObservableObjectPublisher {
    
    private class Conduit: Hashable {
        
        fileprivate func send() {
            abstractMethod()
        }
        
        fileprivate static func == (lhs: Conduit, rhs: Conduit) -> Bool {
            return lhs === rhs
        }
        
        fileprivate func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }
    
    private final class Inner<Downstream: Subscriber>
    : Conduit,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Void, Downstream.Failure == Never
    {
        private enum State {
            case initialized
            case active
            case terminal
        }
        
        private weak var parent: ObservableObjectPublisher?
        // 存储, 真正的下游节点.
        private let downstream: Downstream
        private let downstreamLock = UnfairRecursiveLock.allocate()
        private let lock = UnfairLock.allocate()
        private var state = State.initialized
        
        init(downstream: Downstream, parent: ObservableObjectPublisher) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            downstreamLock.deallocate()
            lock.deallocate()
        }
        
        override func send() {
            lock.lock()
            let state = self.state
            lock.unlock()
            if state == .active {
                downstreamLock.lock()
                // 触发下游节点接收事件. 因为 Output 是 Never, 所以只有事件, 没有数据.
                _ = downstream.receive()
                downstreamLock.unlock()
            }
        }
        
        // 仅仅是状态的更改, 在这里面, 是没有 demand 的管理的.
        // 在接收到上游 Next 数据之后, 如果下游没有 Demand, 还是不进行发送 .
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            if state == .initialized {
                state = .active
            }
            lock.unlock()
        }
        
        // 当下游触发了 cancel 之后, 就是将自己从 dispatch 表中进行删除.
        func cancel() {
            lock.lock()
            state = .terminal
            lock.unlock()
            parent?.remove(self)
        }
        
        var description: String { return "ObservableObjectPublisher" }
        
        var customMirror: Mirror {
            let children = CollectionOfOne<Mirror.Child>(("downstream", downstream))
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any {
            return description
        }
    }
}
