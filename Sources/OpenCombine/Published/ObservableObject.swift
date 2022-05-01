
/// A type of object with a publisher that emits before the object has changed.
///
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

private protocol _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

#if swift(>=5.1)
extension Published: _ObservableObjectProperty {}

extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    
    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {
        var installedPublisher: ObservableObjectPublisher?
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {
                guard let property = property as? _ObservableObjectProperty else {
                    // Visit other fields until we meet a @Published field
                    continue
                }
                
                // Now we know that the field is @Published.
                if let alreadyInstalledPublisher = property.objectWillChange {
                    installedPublisher = alreadyInstalledPublisher
                    // Don't visit other fields, as all @Published fields
                    // already have a publisher installed.
                    break
                }
                
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
                
                property.objectWillChange = lazilyCreatedPublisher
                
                // Continue visiting other fields.
            }
            reflection = aClass.superclassMirror
        }
        return installedPublisher ?? ObservableObjectPublisher()
    }
}

#endif

/// A publisher that publishes changes from observable objects.
// 一个引用值.
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
