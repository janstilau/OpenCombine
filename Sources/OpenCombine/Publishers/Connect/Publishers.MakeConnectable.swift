extension Publisher where Failure == Never {
    /// Creates a connectable wrapper around the publisher.
    // 这里其实说的很清楚了, 就是一个 wrapper. 没有承担起一个 Operator 的责任.
    
    /// In the following example, `makeConnectable()` wraps its upstream publisher
    /// (an instance of `Publishers.Share`) with a `ConnectablePublisher`.
    /// Without this, the first sink subscriber would receive all the elements from the sequence
    /// publisher and cause it to complete before the second subscriber attaches.
    /// By making the publisher connectable, the publisher doesn’t produce any elements
    /// until after the `connect()` call.
    
    ///      let subject = Just<String>("Sent")
    ///      let pub = subject
    ///          .share()
    ///          .makeConnectable()
    ///      cancellable1 = pub.sink { print ("Stream 1 received: \($0)")  }
    ///
    ///      // For example purposes, use DispatchQueue to add a second subscriber
    ///      // a second later, and then connect to the publisher a second after that.
    ///      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    ///          self.cancellable2 = pub.sink { print ("Stream 2 received: \($0)") }
    ///      }
    ///      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    ///          self.connectable = pub.connect()
    ///      }
    ///      // Prints:
    ///      // Stream 2 received: Sent
    ///      // Stream 1 received: Sent
    ///
    ///  > Note: The `connect()` operator returns a `Cancellable` instance that you must
    ///  retain. You can also use this instance to cancel publishing.
    ///
    /// - Returns: A `ConnectablePublisher` wrapping this publisher.
    public func makeConnectable() -> Publishers.MakeConnectable<Self> {
        return .init(upstream: self)
    }
    // makeConnectable 的作用, 其实是尽量的晚一点真正的产生信号数据.
}

// MakeConnectable 这个类, 完全就是一个代理类.
// 他的作用, 就是生成一个 Multicast, 然后 Multicast 设计完成 Publisher 的工作.
extension Publishers {
    /// A publisher that provides explicit connectability to another publisher.
    
    /// `Publishers.MakeConnectable` is a `ConnectablePublisher`, which allows you to
    /// perform configuration before publishing any elements. Call `connect()` on this
    /// publisher when you want to attach to its upstream publisher and start producing
    /// elements.
    
    /// Use the `makeConnectable()` operator to wrap an upstream publisher with
    /// an instance of this publisher.
    
    public struct MakeConnectable<Upstream: Publisher>: ConnectablePublisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        // 直接使用 PassthroughSubject 了 .
        private let inner: Multicast<Upstream, PassthroughSubject<Output, Failure>>
        
        /// Creates a connectable publisher, attached to the provide upstream publisher.
        ///
        /// - Parameter upstream: The publisher from which to receive elements.
        public init(upstream: Upstream) {
            // 这里 .init(), 是 PassthroughSubject 的构造函数创建. 让人难以理解.
            inner = upstream.multicast(subject: .init())
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Failure == Failure, Downstream.Input == Output
        {
            inner.subscribe(subscriber)
        }
        
        public func connect() -> Cancellable {
            return inner.connect()
        }
    }
}
