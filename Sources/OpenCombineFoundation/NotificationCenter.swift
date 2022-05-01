
import Foundation
import OpenCombine

extension NotificationCenter {
    
    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `NotificationCenter` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `NotificationCenter.Publisher`,
    /// because Swift is unable to understand which `Publisher`
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `NotificationCenter.OCombine.Publisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine {
        
        public let center: NotificationCenter
        
        public init(_ center: NotificationCenter) {
            self.center = center
        }
        
        /// A publisher that emits elements when broadcasting notifications.
        public struct Publisher: OpenCombine.Publisher {
            
            public typealias Output = Notification
            
            public typealias Failure = Never
            
            /// The notification center this publisher uses as a source.
            public let center: NotificationCenter
            
            /// The name of notifications published by this publisher.
            public let name: Notification.Name
            
            /// The object posting the named notification.
            public let object: AnyObject?
            
            /// Creates a publisher that emits events when broadcasting notifications.
            ///
            /// - Parameters:
            ///   - center: The notification center to publish notifications for.
            ///   - name: The name of the notification to publish.
            ///   - object: The object posting the named notification. If `nil`,
            ///     the publisher emits elements for any object producing a notification
            ///     with the given name.
            public init(center: NotificationCenter,
                        name: Notification.Name,
                        object: AnyObject? = nil) {
                self.center = center
                self.name = name
                self.object = object
            }
            
            public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Never, Downstream.Input == Notification
            {
                // 这里, 生成的 Subscription 是真正的响应链条里面的节点.
                let subscription = Notification.Subscription(center: center,
                                                             name: name,
                                                             object: object,
                                                             downstream: subscriber)
                // 在这里, 生成了 Notification.Subscription 对象, 然后交给下游, 让下游进行 Demand 的管理.
                subscriber.receive(subscription: subscription)
            }
        }
        
        /// Returns a publisher that emits events when broadcasting notifications.
        ///
        /// - Parameters:
        ///   - name: The name of the notification to publish.
        ///   - object: The object posting the named notification. If `nil`, the publisher
        ///     emits elements for any object producing a notification with the given
        ///     name.
        /// - Returns: A publisher that emits events when broadcasting notifications.
        public func publisher(for name: Notification.Name,
                              object: AnyObject? = nil) -> Publisher {
            // 这里返回的, 就是 Publisher 对象. 绑定了类型, 就可以直接使用 init 函数了.
            return .init(center: center, name: name, object: object)
        }
    }
    
#if !canImport(Combine)
    /// A publisher that emits elements when broadcasting notifications.
    public typealias Publisher = OCombine.Publisher
#endif
}

extension NotificationCenter {
    
    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `NotificationCenter` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `NotificationCenter.default.publisher(for: name)`,
    /// because Swift is unable to understand which `publisher` method
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `NotificationCenter.default.ocombine.publisher(for: name)`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine { return .init(self) }
    
#if !canImport(Combine)
    /// Returns a publisher that emits events when broadcasting notifications.
    ///
    /// - Parameters:
    ///   - name: The name of the notification to publish.
    ///   - object: The object posting the named notification. If `nil`, the publisher
    ///     emits elements for any object producing a notification with the given name.
    /// - Returns: A publisher that emits events when broadcasting notifications.
    public func publisher(for name: Notification.Name,
                          object: AnyObject? = nil) -> OCombine.Publisher {
        return ocombine.publisher(for: name, object: object)
    }
#endif
}

extension NotificationCenter.OCombine.Publisher: Equatable {
    public static func == (lhs: NotificationCenter.OCombine.Publisher,
                           rhs: NotificationCenter.OCombine.Publisher) -> Bool {
        return lhs.center == rhs.center &&
        lhs.name == rhs.name &&
        lhs.object === rhs.object
    }
}

// 大量使用了嵌套类型.
extension Notification {
    
    // 真正的, 节点对象.
    fileprivate final class Subscription<Downstream: Subscriber>
    : OpenCombine.Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Notification,
          Downstream.Failure == Never
    {
        private let lock = UnfairLock.allocate()
        
        fileprivate let downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate var demand = Subscribers.Demand.none
        
        private var center: NotificationCenter?
        
        private let name: Name
        
        private var object: AnyObject?
        
        private var observation: AnyObject? // Imperative 的 Obj.
        
        fileprivate init(center: NotificationCenter,
                         name: Notification.Name,
                         object: AnyObject?,
                         downstream: Downstream) {
            self.center = center
            self.name = name
            self.object = object
            // 这里, 对 downstream 进行了强引用.
            self.observation = center
                .addObserver(forName: name, object: object, queue: nil) { [weak self] in
                    self?.didReceiveNotification($0, downstream: downstream)
                }
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 每次, 收到通知之后, 其实会有 demand 的 -1 操作的.
        private func didReceiveNotification(_ notification: Notification,
                                            downstream: Downstream) {
            lock.lock()
            // 如果, demand 已经降低到 0 了, 那么就不会给后续发射信号了. 
            guard demand > 0 else {
                lock.unlock()
                return
            }
            demand -= 1
            lock.unlock()
            downstreamLock.lock()
            // 然后, 在这里, 才会真正通知后方节点, 进行数据的接受.
            let newDemand = downstream.receive(notification)
            downstreamLock.unlock()
            lock.lock()
            // demand 根据后续节点的返回值, 进行管理.
            demand += newDemand
            lock.unlock()
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            // 在这里, 对于 demand 进行了更改.
            self.demand += demand
            lock.unlock()
        }
        
        func cancel() {
            lock.lock()
            guard let center = self.center.take(),
                  let observation = self.observation.take() else {
                      lock.unlock()
                      return
                  }
            
            self.object = nil
            lock.unlock()
            // 这里, 对于 downStream 进行了强引用的解除. 
            center.removeObserver(observation)
        }
        
        fileprivate var description: String { return "NotificationCenter Observer" }
        
        fileprivate var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("center", center as Any),
                ("name", name),
                ("object", object as Any),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }
        
        fileprivate var playgroundDescription: Any { return description }
    }
}
