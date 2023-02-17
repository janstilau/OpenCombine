// 这种行为, Failure 必须是 Never 才可以.
// 因为是赋值, 如果上游出错了, 出错信息流转到这里, 其实是没有办法处理的. 所以, 必须是 Never.
// 这也迫使了, 上游节点一定要做错误的处理. 不然直接使用 assign 会出问题的.
extension Publisher where Failure == Never {
    /// Assigns each element from a publisher to a property on an object.
    
    /// Use the `assign(to:on:)` subscriber when you want to set a given property each
    /// time a publisher produces a value.
    
    /// In this example, the `assign(to:on:)` sets the value of the `anInt` property on
    /// an instance of `MyClass`:
    
    ///
    ///
    ///     class MyClass {
    ///         var anInt: Int = 0 {
    ///             didSet {
    ///                 print("anInt was set to: \(anInt)", terminator: "; ")
    ///             }
    ///         }
    ///     }
    
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
        
        let subscriber = Subscribers.Assign(object: object,
                                            keyPath: keyPath)
        // 回溯创建整个链条的起点.
        /*
         当我们实现一个 Publisher 的时候, 一定要实现  receive<Subscriber: OpenCombine.Subscriber>(subscriber: Subscriber) 这个方法, 但是这个方法的调用, 是在创建响应链路的时候.
         我们实现这个协议, 并不主动调用这个协议. 这是因为这个协议是被模板方法在使用.
         模板方法, 固定的算法流程, 使用协议提供的抽象, 来搭建固定的行为模式.
        */
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}



extension Subscribers {
    // A simple subscriber that assigns received elements to a property indicated by a key path.
    // 这个 Subsciber, 自动要进行 Cancellable 的实现.
    public final class Assign<Root, Input>: Subscriber, // 承接上端的数据.
                                            Cancellable, // 末尾节点, 不需要接受 Demand 的管理.
                                            CustomStringConvertible,
                                            CustomReflectable,
                                            CustomPlaygroundDisplayConvertible
    {
        // 上层节点的 Error, 必须是 Never 类型的才可以.
        // Assign 不是不会接收到结束事件, 而是不可以接收到代表着 Failure 的结束事件. 
        public typealias Failure = Never
        
        private let lock = UnfairLock.allocate()
        
        /// The object that contains the property to assign.
        /// The subscriber holds a strong reference to this object until the upstream
        /// publisher calls `Subscriber.receive(completion:)`, at which point
        /// the subscriber sets this property to `nil`.
        // 存储一下, 要被赋值的对象. 这里必须是强引用.
        // 只有自己显示的进行 cancel 的情况下, 才应该进行资源的释放 .
        
        // 这里是强引用
        public private(set) var toAssignObject: Root?
        
        /// The key path that indicates the property to assign.
        // KeyPath 是一个很特殊的数据结构.
        public let keyPath: ReferenceWritableKeyPath<Root, Input>
        
        // 一个惯例实现.
        private var status = SubscriptionStatus.awaitingSubscription
        
        /// Creates a subscriber to assign the value of a property indicated by
        /// a key path.
        public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) {
            self.toAssignObject = object
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
            // 因为上游其实在存储着 Subscriber 的指针, 这里又存储着上游的指针, 循环引用成立.
            status = .subscribed(subscription)
            lock.unlock()
            // 必须调用 requestDemand 方法.
            // Publisher 如果尊重 Pull 原型的话, 不调用那么 Subscriber 永远不能接收到数据.
            subscription.request(.unlimited)
        }
        
        public func receive(_ value: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status, let object = self.toAssignObject else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            // Subscriber 就是末端, 所以不会有再次后续节点的接受. 而是直接机型赋值.
            // object 必然是一个引用类型.
            // KeyPath 必然是一个 WriteAble 的对象.
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
        
        // 对于 Cancellable 的实现. 
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
        
        // 对于 Assign 来说, 它是终点,
        private func terminateAndConsumeLock() {
            // enum 的状态改变, 完成了对于上游 subscription 的释放.
            status = .terminal
            withExtendedLifetime(toAssignObject) {
                // 触发, 存储的 root 对象的释放 .
                // 在 Assign 里面, 资源就是强引用的各个对象.
                toAssignObject = nil
                lock.unlock()
            }
        }
        
        
        
        
        /// A textual representation of this subscriber.
        public var description: String { return "Assign \(Root.self)." }
        
        /// A mirror that reflects the subscriber.
        public var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("object", toAssignObject as Any),
                ("keyPath", keyPath),
                ("status", status as Any)
            ]
            return Mirror(self, children: children)
        }
        
        public var playgroundDescription: Any { return description }
    }
}
