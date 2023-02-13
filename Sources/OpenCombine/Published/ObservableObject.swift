/*
 
 ObservableObject -> Model 这里面会有 @Published 类型的数据.
 @Published
 
 ObservableObject 会有一个 ObjectWillChangePublisher 的属性. 
 ObjectWillChangePublisher <- ObservableObjectPublisher
 
 这是三个不同的概念.
 */

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

///     let john = Contact(name: "John Appleseed", age: 24)
///     cancellable = john.objectWillChange
///         .sink { _ in
///             print("\(john.age) will change")
///         }
///     print(john.haveBirthday())
///     // Prints "24 will change"
///     // Prints "25"

// 这是非常重要的一个 Protocol. SwiftUI 的各种监听, 都是建立在 ObservableObject 的基础上的.
// 这必须是一个引用类.
public protocol ObservableObject: AnyObject {
    
    /// The type of publisher that emits before the object has changed.
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher
    // 不可能出现失败的情况, 因为是, Object 的属性发生改变.
    // 失败, 是相应链条的业务场景中, 触发了失败的
    where ObjectWillChangePublisher.Failure == Never
    
    /// A publisher that emits before the object has changed.
    // 对于 ObservableObject 类型的 Model 来说, 他会有一个 objectWillChange 这个 publisher, 供外界进行使用.
    var objectWillChange: ObjectWillChangePublisher { get }
}

// 这里是一个小技巧, 专门做一个私有协议, 然后让特定的类型来实现该协议.
// 其实, 就是类型判断. 不过如果类型过多的话, 使用协议判断, 代码会更加的清晰.
private protocol _ObservableObjectProperty {
    var _objectWillChange: ObservableObjectPublisher? { get nonmutating set }
}

#if swift(>=5.1)
// 只有 Published 实现了这个协议.
// 这是一个泛型, 可以直接完成对于协议的遵守.
extension OpenPublished: _ObservableObjectProperty {}

// ObservableObject 的 objectWillChange 会自动合成. 就是在 get 的时候, 进行了懒加载.
// 并且, 对于每个 Published 属性中, 隐藏的 Publisher 的 objectWillChange 进行了赋值操作.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    
    /// A publisher that emits before the object has changed.
    // 一个 Obj 只会有一个 objectWillChange 对象, 这个对象, 是存到了 @Published 属性里面了.
    // 因为 Protocol 无法增加实例变量
    public var objectWillChange: ObservableObjectPublisher {
        var thePublisherForSelf: ObservableObjectPublisher?
        
        // 使用元信息, 查找到 Published 类型. 对里面的值 objectWillChange 属性进行了赋值 .
        // 这里是将所有的, 包括父类的 @published 属性, 都增加了同样的一个 Publisher 作为信号源.
        var reflection: Mirror? = Mirror(reflecting: self)
        while let aClass = reflection {
            for (_, property) in aClass.children {
                // 首先判断, 是否是 Published 的类型.
                // 使用 is OpenPublished 是无法成功的, 因为 OpenPublished 是泛型, 不能单独当做
                guard let property = property as? _ObservableObjectProperty else {
                    continue
                }
//                guard let property = property is OpenPublished else {
//                    continue
//                }
                
                // 然后判断, 是否 Published 类型, 是否已经有了 objectWillChange 属性了.
                // 对于一个类型来说, 如果一个 property 有了, 就是这个类型的 property 都有了.  break.
                if let alreadyInstalledPublisher = property._objectWillChange {
                    thePublisherForSelf = alreadyInstalledPublisher
                    // Don't visit other fields, as all @Published fields
                    // already have a publisher installed.
                    break
                }
                
                // Okay, this field doesn't have a publisher installed.
                // This means that other fields don't have it either
                // (because we install it only once and fields can't be added at runtime).
                // 原来可以这样初始化, 之前还一直用 = {}() 这种方式.
                var lazilyCreatedPublisher: ObjectWillChangePublisher {
                    if let publisher = thePublisherForSelf {
                        return publisher
                    }
                    let publisher = ObservableObjectPublisher()
                    thePublisherForSelf = publisher
                    return publisher
                }
                // 注意, 这里 lazilyCreatedPublisher 的构建过程.
                // 如果 installedPublisher 有值了, 那么就使用 installedPublisher 的值.
                // 所以, 最终所有的 Property 都是使用的同样的一个 installedPublisher.
                // 真的是令人困恼的代码.
                property._objectWillChange = lazilyCreatedPublisher
                // Continue visiting other fields.
            }
            reflection = aClass.superclassMirror
        }
        
        // 如果, 没有 installedPublisher, 那就是里面根本就没有 @Published 属性. 随便给一个值.
        return thePublisherForSelf ?? ObservableObjectPublisher()
    }
}

#endif

/// A publisher that publishes changes from observable objects.
/*
 实现, 是 Subject 的实现.
 完成的, 是 Publisher 的功能.
 */
/*
 一般来说, Publisher 都是一个生成器, 每一个 Publisher 串联在一起, 在真正的进行生成响应链条的时候, 才会生成对应的节点.
 但是, ObservableObjectPublisher 是直接和一个引用对象挂钩的.
 这个 Publisher 只会有一个. 从这个意义上来说, 很像是 Subject.
 所以里面的实现, 和 Subject 非常像.
 */


/*
 想一下, ObservableObject 的实现方案.
 当, ObservableObject 内有一个 @Published 属性发生改变的时候, ObservableObject 的 objectWillChange 都要发出通知.
 这就要求了, ObservableObjectPublisher 一定要有一个办法, 使得所有属性的监听这件事归并到一个地方.
 这样, 在所有的 ObservableObjectPublisher.send 触发的时候, 都会引起后续节点的 receiveOuput 的触发.
 这个机制, 是在 ObservableObjectPublisher 内部完成的.
 这里面有存储, 这是一个引用语义的值.
 */
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
    
    // 当, 收到了下游节点的 attach 请求之后, 是将下游节点进行包装, 然后存储到 connections 里面.
    // 以便自己调用 send 的时候, 将发生了改变这件事, 通过存储的 connections 进行分发.
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
