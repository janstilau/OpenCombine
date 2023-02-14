
import Foundation
import OpenCombine

extension NotificationCenter {
    
    public struct OCombine {
        
        // 类似于 base 的含义.
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
            
            // 对于 Publisher 来说, 主要是收集工作.
            public init(center: NotificationCenter,
                        name: Notification.Name,
                        object: AnyObject? = nil) {
                self.center = center
                self.name = name
                self.object = object
            }
            
            // Publisher 收集好了数据, 当真正的收到了后方节点的 attach 请求之后, 就会生成真正的 Subscription 对象, 在这里, 这个对象是响应链路的头结点.
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
            // 惯例实现, Publisher 的构建方法, 主要就是进行信息的收集.
            return .init(center: center, name: name, object: object)
        }
    }
    
#if !canImport(Combine)
    /// A publisher that emits elements when broadcasting notifications.
    public typealias Publisher = OCombine.Publisher
#endif
}

extension NotificationCenter {
    
    // 这种方式, 就是各种 Extensnion 的处理方式. 各种 Extension, 都是一个值语义的对象, 每次使用的时候, 都是随用随创建.
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
        return self.ocombine.publisher(for: name, object: object)
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
    
    // 这是一个 Subscription, 是因为, 他要收到后面节点的 Request Demand 的请求 和 cancel 请求.
    // 这不是一个 Subscriber, 是一位, 他是一个头结点. 不会 attach 到其他节点的后面.
    fileprivate final class Subscription<Downstream: Subscriber>
    : OpenCombine.Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Notification,
    // 不会出错.
    // 这是一个头结点, 所以, 它不用作为一个 Subscriber 存在.
    Downstream.Failure == Never
    {
        // 大量的, Private 的权限控制. 甚至整个类型, 都是 Private 的.
        // 这是一个非常好的习惯.
        private let lock = UnfairLock.allocate()
        
        fileprivate let downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate var demand = Subscribers.Demand.none
        
        
        // 各种, 需要外界传入进来的对象, 直接就是 Init 方法里面传递进来就好了
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
            // 使用, Notificaiton 的原始 API, 对于通知回调这件事, 进行了注册.
            self.observation = center
                .addObserver(forName: name, object: object, queue: nil) { [weak self] in
                    self?.didReceiveNotification($0, downstream: downstream)
                }
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 实际上, 每次通知发送的时候, 该方法都会被调用. 这是利用了原始的 API 的功能.
        // 但是, 为了尊重 Pull, 专门的设计一个 Notification 的 Subscription 出来.
        // 在这个类里面, 进行了 Demand 的管理. 当新的 Notification 来临的时候, 只有 Demand 符合管理预期, 才会传给自己的 Downstream.
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
        
        // 下游 demand 调整, 这里仅仅是记录 demand 的量.
        // 因为这个节点没有缓存当前值的概念, 所以不会在下游节点 demand 变化的时候, 发送自己的存储值.
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            // 在这里, 对于 demand 进行了更改.
            self.demand += demand
            lock.unlock()
        }
        
        // Cancel, 则是将自己从 NotificaitonCenter 里面移除.
        func cancel() {
            lock.lock()
            // 这里是 optional 的 take 函数.
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
