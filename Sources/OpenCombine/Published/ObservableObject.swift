/// A type of object with a publisher that emits before the object has changed.
///
/// By default an `ObservableObject` synthesizes an `objectWillChange` publisher that
/// emits the changed value before any of its `@Published` properties changes.
///
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

/// 一种具有在对象发生更改之前发出的发布者的对象类型。
///
/// 默认情况下，ObservableObject 会合成一个 objectWillChange 发布者，在其任何 @Published 属性更改之前发出更改的值。
///
/// swift /// class Contact: ObservableObject { /// @Published var name: String /// @Published var age: Int /// /// init(name: String, age: Int) { /// self.name = name /// self.age = age /// } /// /// func haveBirthday() -> Int { /// age += 1 /// } /// } /// /// let john = Contact(name: "John Appleseed", age: 24) /// cancellable = john.objectWillChange /// .sink { _ in /// print("\(john.age) 将要发生改变") /// } /// print(john.haveBirthday()) /// // 打印 "24 将要发生改变" /// // 打印 “25" /// ///
/// 在上面的例子中，objectWillChange 发布者在 john.age 属性发生更改之前发出，然后通过 sink 订阅者进行捕获并打印。
public protocol ObservableObject: AnyObject {

    /// The type of publisher that emits before the object has changed.
    // 执行了一个关联类型, associatedtype ObjectWillChangePublisher: Publisher
    // 如果这个关联类型, 里面的类型 Failure 是 Nevel, 那么这个关联类型有一个默认值, 就是 ObservableObjectPublisher
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
        where ObjectWillChangePublisher.Failure == Never

    /// A publisher that emits before the object has changed.
    var objectWillChange: ObjectWillChangePublisher { get }
}

// 这其实就是一个特殊的标识, 用来进行下方的判断的.
private protocol _ObservableObjectProperty {
    var objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

#if swift(>=5.1)
extension Published: _ObservableObjectProperty {}

// ObservableObject 用来生命特殊标识的.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {

    /// A publisher that emits before the object has changed.
    public var objectWillChange: ObservableObjectPublisher {
        var installedPublisher: ObservableObjectPublisher?
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {
                // 在这里, 用来查找所有的 Published 标识多的属性.
                guard let property = property as? _ObservableObjectProperty else {
                    // Visit other fields until we meet a @Published field
                    continue
                }

                // Now we know that the field is @Published.
                // 如果, 这个 Property 已经有了 objectWillChange, 那么也就不赋值了. 
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

                // 给这个对象的, 所有的 @Published property, 都增加了相同的 ObservableObjectPublisher 对象. 
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
// 这是一个类似于 Subject 的实现.
public final class ObservableObjectPublisher: Publisher {

    // ObservableObjectPublisher 不发送数据, 仅仅是发送事件.
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

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Void, Downstream.Failure == Never
    {
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

        // 一个弱引用.
        private weak var parent: ObservableObjectPublisher?
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
                _ = downstream.receive()
                downstreamLock.unlock()
            }
        }

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
