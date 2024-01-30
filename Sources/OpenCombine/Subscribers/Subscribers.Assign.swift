//
//  Subscribers.Assign.swift
//
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

extension Subscribers {
    
    /// A simple subscriber that assigns received elements to a property indicated by
    /// a key path.
    public final class Assign<Root, Input>: Subscriber,
                                            Cancellable,
                                            CustomStringConvertible,
                                            CustomReflectable,
                                            CustomPlaygroundDisplayConvertible
    {
        // 不能出错.
        public typealias Failure = Never
        
        private let lock = UnfairLock.allocate()
        
        /// The object that contains the property to assign.
        ///
        /// The subscriber holds a strong reference to this object until the upstream
        /// publisher calls `Subscriber.receive(completion:)`, at which point
        /// the subscriber sets this property to `nil`.
        // 这里有一个强引用.
        public private(set) var object: Root?
        
        /// The key path that indicates the property to assign.
        public let keyPath: ReferenceWritableKeyPath<Root, Input>
        
        private var status = SubscriptionStatus.awaitingSubscription
        
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
        
        /// Creates a subscriber to assign the value of a property indicated by
        /// a key path.
        ///
        /// - Parameters:
        ///   - object: The object that contains the property. The subscriber assigns
        ///     the object’s property every time it receives a new value.
        ///   - keyPath: A key path that indicates the property to assign. See
        ///     [Key-Path Expression](https://docs.swift.org/swift-book/ReferenceManual/Expressions.html#ID563)
        ///     in _The Swift Programming Language_ to learn how to use key paths to
        ///     specify a property of an object.
        public init(object: Root, keyPath: ReferenceWritableKeyPath<Root, Input>) {
            self.object = object
            self.keyPath = keyPath
        }
        
        deinit {
            lock.deallocate()
        }
        
        public func receive(subscription: Subscription) {
            lock.lock()
            // 惯例, 需要保持上游节点的强引用.
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            // Assign, 对于上游是无限的索取.
            subscription.request(.unlimited)
        }
        
        public func receive(_ value: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = status, let object = self.object else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            // 接收到上游的数据, 就是使用 keypath, 进行赋值.
            object[keyPath: keyPath] = value
            return .none
        }
        
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
            subscription.cancel()
        }
        
        private func terminateAndConsumeLock() {
#if DEBUG
            lock.assertOwner()
#endif
            status = .terminal
            
            // We MUST release the object AFTER unlocking the lock,
            // since releasing it may trigger execution of arbitrary code,
            // for example, if the object has a deinit.
            // When the object deallocates, its deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            
            // 在这, 真正的进行了引用的清楚. 
            withExtendedLifetime(object) {
                object = nil
                lock.unlock()
            }
        }
    }
}

extension Publisher where Failure == Never {
    
    /// Assigns each element from a publisher to a property on an object.
    ///
    /// Use the `assign(to:on:)` subscriber when you want to set a given property each
    /// time a publisher produces a value.
    ///
    /// In this example, the `assign(to:on:)` sets the value of the `anInt` property on
    /// an instance of `MyClass`:
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
    ///
    ///  > Important: The `Subscribers.Assign` instance created by this operator maintains
    ///  a strong reference to `object`, and sets it to `nil` when the upstream publisher
    ///  completes (either normally or with an error).
    ///
    /// - Parameters:
    ///   - keyPath: A key path that indicates the property to assign. See
    ///     [Key-Path Expression](https://docs.swift.org/swift-book/ReferenceManual/Expressions.html#ID563)
    ///     in _The Swift Programming Language_ to learn how to use key paths to specify
    ///     a property of an object.
    ///   - object: The object that contains the property. The subscriber assigns
    ///     the object’s property every time it receives a new value.
    /// - Returns: An `AnyCancellable` instance. Call `cancel()` on this instance when you
    ///   no longer want the publisher to automatically assign the property.
    ///   Deinitializing this instance will also cancel automatic assignment.
    
    /// 将发布者的每个元素分配给对象上的属性。
    ///
    /// 当您希望在每次发布者产生值时设置给定属性时，请使用 `assign(to:on:)` 订阅者。
    ///
    /// 在此示例中，`assign(to:on:)` 将值设置为 `MyClass` 实例上的 `anInt` 属性：
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
    ///     // 打印: "anInt was set to: 0; anInt was set to: 1; anInt was set to: 2"
    
    // 这里有强引用. 只有上游完毕了之后, 才会把它关闭了.
    ///  > 重要提示: 此操作符创建的 `Subscribers.Assign` 实例对 `object` 保持强引用，并在上游发布者完成（正常或错误完成）时将其设置为 `nil`。
    ///
    /// - Parameters:
    ///   - keyPath: 指示要分配的属性的关键路径。请参阅
    ///     [Key-Path 表达式](https://docs.swift.org/swift-book/ReferenceManual/Expressions.html#ID563)
    ///     在 _The Swift Programming Language_ 中了解如何使用关键路径指定对象的属性。
    ///   - object: 包含属性的对象。订阅者每次接收到新值时都会分配对象的属性。
    /// - Returns: 一个 `AnyCancellable` 实例。当您不再希望发布者自动分配属性时，请在此实例上调用 `cancel()`。
    ///   销毁此实例也将取消自动分配。

    public func assign<Root>(to keyPath: ReferenceWritableKeyPath<Root, Output>,
                             on object: Root) -> AnyCancellable {
        let subscriber = Subscribers.Assign(object: object, keyPath: keyPath)
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
