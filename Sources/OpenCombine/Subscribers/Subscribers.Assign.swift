
// 这种行为, Failure 必须是 Never 才可以.
extension Publisher where Failure == Never {
    /// Assigns each element from a publisher to a property on an object.
    
    /// Use the `assign(to:on:)` subscriber when you want to set a given property each
    /// time a publisher produces a value.
    
    /// In this example, the `assign(to:on:)` sets the value of the `anInt` property on
    /// an instance of `MyClass`:
    //
    ///
    ///     class MyClass {
    ///         var anInt: Int = 0 {
    ///             didSet {
    ///                 print("anInt was set to: \(anInt)", terminator: "; ")
    ///             }
    ///         }
    ///     }
    ///
    ///     var myObject = MyClass()
    ///     let myRange = (0...2)
    ///     cancellable = myRange.publisher
    ///         .assign(to: \.anInt, on: myObject)
    ///
    ///     // Prints: "anInt was set to: 0; anInt was set to: 1; anInt was set to: 2"
    
    // 这个 Subscriber 对于被赋值的 Object 有着强引用.
    ///  > Important: The `Subscribers.Assign` instance created by this operator maintains
    ///  a strong reference to `object`, and sets it to `nil` when the upstream publisher
    ///  completes (either normally or with an error).
    ///
    /// - Parameters:
    ///   - keyPath: A key path that indicates the property to assign.
    ///   核心的内容就是这里, 每次收到数据之后, 给 Object 进行赋值, 使用 keypath 的方式.
    ///   - object: The object that contains the property. The subscriber assigns
    ///     the object’s property every time it receives a new value.
    
    /// - Returns: An `AnyCancellable` instance. Call `cancel()` on this instance when you
    ///   no longer want the publisher to automatically assign the property.
    ///   Deinitializing this instance will also cancel automatic assignment.
    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                             on object: Root) -> AnyCancellable {
        let subscriber = Subscribers.Assign(object: object, keyPath: keyPath)
        subscribe(subscriber)
        // Combine 中, 只有最后的末端节点注册, 才返回 cancellable 对象.
        // 或者 connect 操作的时候.
        return AnyCancellable(subscriber)
    }
}



extension Subscribers {
    // A simple subscriber that assigns received elements to a property indicated by a key path.
    public final class Assign<Root, Input>: Subscriber, // 承接上端的数据.
                                            Cancellable, // 末尾节点, 不需要接受 Demand 的管理.
                                            CustomStringConvertible,
                                            CustomReflectable,
                                            CustomPlaygroundDisplayConvertible
    {
        // 上层节点的 Error, 必须是 Never 类型的才可以.
        public typealias Failure = Never
        
        private let lock = UnfairLock.allocate()
        
        /// The object that contains the property to assign.
        ///
        /// The subscriber holds a strong reference to this object until the upstream
        /// publisher calls `Subscriber.receive(completion:)`, at which point
        /// the subscriber sets this property to `nil`.
        // 存储一下, 要被赋值的对象. 这里必须是强引用.
        // 只有自己显示的进行 cancel 的情况下, 才应该进行资源的释放 .
        
        // 这里是强引用
        public private(set) var object: Root?
        
        /// The key path that indicates the property to assign.
        // KeyPath 是一个很特殊的数据结构.
        public let keyPath: ReferenceWritableKeyPath<Root, Input>
        
        // 一个惯例实现.
        private var status = SubscriptionStatus.awaitingSubscription
        
        /// Creates a subscriber to assign the value of a property indicated by
        /// a key path.
        public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) {
            self.object = object
            self.keyPath = keyPath
        }
        
        // Subscriber 的内存其实不会和 Cancel 进行绑定, 真正的绑定的, 是 Cancelable 对象 .
        deinit {
            lock.deallocate()
        }
        
        public func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 存储一下上游的节点.
            // 循环引用一下.
            // 强引用的实现.
            status = .subscribed(subscription)
            lock.unlock()
            // 必须调用 requestDemand 方法.
            // Publisher 如果尊重 Pull 原型的话, 不调用那么 Subscriber 永远不能接收到数据.
            subscription.request(.unlimited)
        }
        
        public func receive(_ value: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status, let object = self.object else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            // Subscriber 就是末端, 所以不会有再次后续节点的接受. 而是直接机型赋值.
            // object 必然是一个引用类型.
            object[keyPath: keyPath] = value
            return .none
        }
        
        // 接收到了完成事件. 这个时候, 上游的资源, 理应已经完成了释放.
        public func receive(completion: Subscribers.Completion<Never>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            terminateAndConsumeLock()
        }
        
        public func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            terminateAndConsumeLock()
            // 触发上游节点的 cancel 操作.
            subscription.cancel()
        }
        
        private func terminateAndConsumeLock() {
            // 消除对于上游节点的引用. 打破了循环引用.
            status = .terminal
            withExtendedLifetime(object) {
                // 触发, 存储的 root 对象的释放 .
                // 在 Assign 里面, 资源就是强引用的各个对象.
                object = nil
                lock.unlock()
            }
        }
        
        
        
        
        /// A textual representation of this subscriber.
        public var description: String { return "Assign \(Root.self)." }
        
        /// A mirror that reflects the subscriber.
        public var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("object", object as Any),
                ("keyPath", keyPath),
                ("status", status as Any)
            ]
            return Mirror(self, children: children)
        }
        
        public var playgroundDescription: Any { return description }
    }
}
