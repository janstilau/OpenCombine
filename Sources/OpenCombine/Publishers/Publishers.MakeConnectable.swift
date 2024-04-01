extension Publisher where Failure == Never {

    /// Creates a connectable wrapper around the publisher.
    ///
    /// In the following example, `makeConnectable()` wraps its upstream publisher
    /// (an instance of `Publishers.Share`) with a `ConnectablePublisher`. Without this,
    /// the first sink subscriber would receive all the elements from the sequence
    /// publisher and cause it to complete before the second subscriber attaches.
    /// By making the publisher connectable, the publisher doesn’t produce any elements
    /// until after the `connect()` call.
    ///
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
    /// - Returns: A `ConnectablePublisher` wrapping this publisher.'
    ///
    /// 创建包装其上游发布者的可连接包装。
    ///
    /// 在以下示例中，`makeConnectable()` 使用 `ConnectablePublisher` 包装其上游发布者（`Publishers.Share` 的实例）。
    /// 如果没有这样做，第一个 sink 订阅者将接收来自序列发布者的所有元素，并导致其在第二个订阅者连接之前完成。
    /// 通过将发布者设为可连接，该发布者在 `connect()` 调用之后才会产生任何元素。
    ///
    ///      let subject = Just<String>("Sent")
    ///      let pub = subject
    ///          .share()
    ///          .makeConnectable()
    ///      cancellable1 = pub.sink { print ("Stream 1 received: \($0)")  }
    ///
    ///      // 举例说明，使用 DispatchQueue 添加第二个订阅者
    ///      // 一秒钟后，然后在之后的一秒钟连接到发布者。
    ///      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    ///          self.cancellable2 = pub.sink { print ("Stream 2 received: \($0)") }
    ///      }
    ///      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    ///          self.connectable = pub.connect()
    ///      }
    ///      // 输出:
    ///      // Stream 2 received: Sent
    ///      // Stream 1 received: Sent
    ///
    /// > 注意: `connect()` 操作符返回一个您必须保留的 `Cancellable` 实例。您还可以使用此实例取消发布。
    ///
    /// - Returns: 包装此发布者的 `ConnectablePublisher`。

    public func makeConnectable() -> Publishers.MakeConnectable<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that provides explicit connectability to another publisher.
    ///
    /// `Publishers.MakeConnectable` is a `ConnectablePublisher`, which allows you to
    /// perform configuration before publishing any elements. Call `connect()` on this
    /// publisher when you want to attach to its upstream publisher and start producing
    /// elements.
    ///
    /// Use the `makeConnectable()` operator to wrap an upstream publisher with
    /// an instance of this publisher.
    public struct MakeConnectable<Upstream: Publisher>: ConnectablePublisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        // Multicast 里面, 存储了上游, 一个 Subject. 然后下游就是链接到这个 Subject 上.
        private let inner: Multicast<Upstream, PassthroughSubject<Output, Failure>>

        /// Creates a connectable publisher, attached to the provide upstream publisher.
        ///
        /// - Parameter upstream: The publisher from which to receive elements.
        public init(upstream: Upstream) {
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
